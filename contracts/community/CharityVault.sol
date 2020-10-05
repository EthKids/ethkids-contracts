pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../ERC20.sol";
import "../RegistryAware.sol";
import "../RegistryInterface.sol";

/**
 * @title CharityVault
 * @dev Vault which holds the assets until the community leader(s) decide to transfer
 * them to the actual charity destination.
 * Deposit and withdrawal calls come only from the actual community contract
 */
contract CharityVault is RegistryAware, Secondary {
    using SafeMath for uint256;

    RegistryInterface public registry;
    uint256 public sumStats;

    event LogStableTokenReceived(
        uint256 amount,
        address indexed account
    );
    event LogStableTokenSent(
        uint256 amount,
        address indexed account
    );

    /**
    * @dev not allowed, can't store ETH
    **/
    function() external {
        //no 'payable' here
    }

    function setRegistry(address _registry) public onlyPrimary {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

    /**
     * @dev Receives it's part in ETH, converts it to a stablecoin and stores it.
     * @param _payee The destination address of the funds.
     */
    function deposit(address _payee) public onlyPrimary payable {
        uint256 _amount = currencyConverter().executeSwapMyETHToStable.value(msg.value)();
        sumStats = sumStats.add(_amount);
        emit LogStableTokenReceived(_amount, _payee);
    }

    /**
     * @dev Withdraw some of accumulated balance for a _payee.
     */
    function withdraw(address payable _payee, uint256 _payment) public onlyPrimary {
        require(_payment > 0 && stableToken().balanceOf(address(this)) >= _payment, "Insufficient funds in the charity fund");
        stableToken().transfer(_payee, _payment);
        emit LogStableTokenSent(_payment, _payee);
    }

    function currencyConverter() internal view returns (CurrencyConverterInterface) {
        return CurrencyConverterInterface(registry.getCurrencyConverter());
    }

    function stableToken() internal view returns (ERC20) {
        return ERC20(currencyConverter().getStableToken());
    }
}

interface CurrencyConverterInterface {
    function executeSwapMyETHToStable() external payable returns (uint256);

    function getStableToken() external view returns (address);
}
