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

    address public DAI_ADDRESS;
    address public ADAI_ADDRESS;

    constructor (address _adai, address _dai) public {
        ADAI_ADDRESS = _adai;
        DAI_ADDRESS = _dai;
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

    function withdrawAllDai() public onlyWhitelisted {
        withdraw(DAI_ADDRESS, ADAI_ADDRESS, 0);
    }

    /**
    * @dev Community triggers the withdrawal from Aave.
    * All aTokens (x communityCount) will be redeemed and the resulting ERC will be distributed among the communities
    * _amount = 0 means 'ALL'
    **/
    function withdraw(address _token, address _atoken, uint _amount) public onlyWhitelisted {
        if (_amount == 0) {
            //all available
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

            //distribute over all communities
            for (uint8 i = 0; i < registry.communityCount(); i++) {
                ERC20(_token).transfer(registry.getCharityVaults()[i], _amount);
            }
        }
    }

    function setRegistry(address _registry) public onlyWhitelistAdmin {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

}
