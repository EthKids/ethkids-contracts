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

    event LogDonationReceived(
        uint256 amount,
        address indexed account
    );
    event LogDonationWithdrawn(
        uint256 amount,
        address indexed account
    );

    /**
    * @dev 'deposit' must be used instead
    **/
    function() external {
        //no 'payable' here
    }

    /**
     * @dev Receives some ETH and stores it.
     * @param _payee the donor's address.
     */
    function deposit(address _payee) public payable {
        sumStats = sumStats.add(msg.value);
        emit LogDonationReceived(msg.value, _payee);
    }

    /**
     * @dev Withdraw some of accumulated balance for a _payee.
     */
    function withdraw(address payable _payee, uint256 _payment) public onlyPrimary {
        require(_payment > 0 && address(this).balance >= _payment, "Insufficient funds in the charity vault");
        _payee.transfer(_payment);
        emit LogDonationWithdrawn(_payment, _payee);
    }

    function setRegistry(address _registry) public onlyPrimary {
        registry = (RegistryInterface)(_registry);
    }

    function getRegistry() public view returns (RegistryInterface) {
        return registry;
    }

}
