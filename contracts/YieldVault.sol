pragma solidity ^0.5.8;

import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./aave/IAToken.sol";
import "./RegistryAware.sol";
import "./ERC20.sol";
import "./YieldVaultInterface.sol";

contract YieldVault is YieldVaultInterface, RegistryAware, WhitelistedRole {

    using SafeMath for uint256;
    RegistryInterface public registry;
    mapping(address => uint256) public withdrawalBacklog;

    /**
     * @dev Payable fallback to receive ETH while converting ERC
     **/
    function() external payable {
    }

    function balance(address _atoken) public view returns (uint256) {
        return IAToken(_atoken).balanceOf(address(this));
    }

    function historicBalance(address _atoken) public view returns (uint256) {
        return balance(_atoken).add(withdrawalBacklog[_atoken]);
    }

    function communityVaultBalance(address _atoken) public view returns (uint256) {
        return balance(_atoken) / registry.communityCount();
    }

    /**
    * @dev Community triggers the withdrawal from Aave.
    * All aTokens (x communityCount) will be redeemed and the resulting ERC will be distributed among the communities
    * _amount = 0 means 'ALL'
    **/
    function withdraw(address _token, address _atoken, uint _amount) public onlyWhitelisted {
        if (_amount == 0) {
            //withdraw all available
            _amount = communityVaultBalance(_atoken);
        } else {
            require(communityVaultBalance(_atoken) >= _amount);
        }

        if (_amount > 0) {
            uint totalAmount = _amount.mul(registry.communityCount());
            IAToken aToken = IAToken(_atoken);
            //if not used as a collateral
            require(aToken.isTransferAllowed(address(this), totalAmount));
            aToken.redeem(totalAmount);
            withdrawalBacklog[_atoken] = withdrawalBacklog[_atoken].add(totalAmount);

            ERC20 token = ERC20(_token);
            //approve for swap
            token.approve(address(currencyConverter()), totalAmount);
            //swap
            currencyConverter().executeSwapMyERCToETH(token, totalAmount);

            //fund the BondingVault
            uint _bondingAllocation = (address(this).balance).mul(10).div(100);
            address payable bondingVaultPayable = address(uint160(address(getRegistry().getBondingVault())));
            bondingVaultPayable.transfer(_bondingAllocation);

            //distribute ETH all over communities
            uint ethAmout = (address(this).balance).div(registry.communityCount());
            for (uint8 i = 0; i < registry.communityCount(); i++) {
                CharityVaultInterface charityVault = CharityVaultInterface(registry.getCharityVaults()[i]);
                charityVault.deposit.value(ethAmout)(msg.sender);
            }
        }
    }

    function currencyConverter() internal view returns (CurrencyConverterInterface) {
        return CurrencyConverterInterface(getRegistry().getCurrencyConverter());
    }

    function setRegistry(address _registry) public onlyWhitelistAdmin {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

}

interface CurrencyConverterInterface {
    function executeSwapMyERCToETH(ERC20 srcToken, uint srcQty) external;
}

interface CharityVaultInterface {
    function deposit(address _payee) external payable;
}
