pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "openzeppelin-solidity/contracts/utils/EnumerableSet.sol";
import "./RegistryInterface.sol";
import "./RegistryAware.sol";
import "./BondingVaultInterface.sol";
import "./community/IDonationCommunity.sol";

/**
 * @title EthKidsRegistry
 * @dev Holds the list of the communities' addresses
 */
contract EthKidsRegistry is RegistryInterface, SignerRole {

    using EnumerableSet for EnumerableSet.AddressSet;

    BondingVaultInterface public bondingVault;
    EnumerableSet.AddressSet private communities;
    address public currencyConverter;

    event CommunityRegistered(address communityAddress);

    /**
    * @dev Default fallback function, just deposits funds to the community
    */
    function() external payable {
        ((address) (bondingVault)).call.value(msg.value)("");
    }

    constructor (address payable _bondingVaultAddress) public {
        require(_bondingVaultAddress != address(0));
        bondingVault = BondingVaultInterface(_bondingVaultAddress);
    }

    function registerCommunity(address _communityAddress) onlySigner public {
        require(communities.add(_communityAddress), 'This community is already present!');
        ((RegistryAware)(_communityAddress)).setRegistry(address(this));
        bondingVault.addWhitelisted(_communityAddress);
        emit CommunityRegistered(_communityAddress);
    }

    function registerCurrencyConverter(address _currencyConverter) onlySigner public {
        currencyConverter = _currencyConverter;
    }

    function removeCommunity(address _address) onlySigner public {
        bondingVault.removeWhitelisted(_address);
        communities.remove(_address);
    }

    function getCommunityAt(uint256 _index) public view returns (IDonationCommunity community) {
        return IDonationCommunity(communities.get(_index));
    }

    function communityCount() public view returns (uint256) {
        return communities.length();
    }

    function sweepVault() public onlySigner {
        bondingVault.sweepVault(msg.sender);
    }

    function getCurrencyConverter() public view returns (address) {
        return currencyConverter;
    }

    function getBondingVault() public view returns (BondingVaultInterface) {
        return bondingVault;
    }


}
