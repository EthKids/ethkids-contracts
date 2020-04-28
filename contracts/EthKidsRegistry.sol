pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "./RegistryInterface.sol";
import "./RegistryAware.sol";
import "./BondingVaultInterface.sol";
import "./community/IDonationCommunity.sol";

/**
 * @title EthKidsRegistry
 * @dev Holds the list of the communities' addresses
 */
contract EthKidsRegistry is RegistryInterface, SignerRole {

    BondingVaultInterface public bondingVault;

    uint256 public communityIndex = 0;
    mapping(uint256 => IDonationCommunity) public communities;
    address public currencyConverter;

    event CommunityRegistered(address communityAddress, uint256 index);

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
        registerCommunityAt(_communityAddress, communityIndex);
        communityIndex++;
    }

    /**
    * @dev Make sure the community has address(this) as one of _signers in order to set registry instance
    **/
    function registerCommunityAt(address _communityAddress, uint256 index) onlySigner public {
        communities[index] = IDonationCommunity(_communityAddress);
        ((RegistryAware)(_communityAddress)).setRegistry(address(this));
        bondingVault.addWhitelisted(_communityAddress);
        emit CommunityRegistered(_communityAddress, index);
    }

    function registerCurrencyConverter(address _currencyConverter) onlySigner public {
        currencyConverter = _currencyConverter;
    }

    function removeCommunity(uint256 _index) onlySigner public {
        bondingVault.removeWhitelisted(address(communities[_index]));
        communities[_index] = IDonationCommunity(address(0));
    }

    function getCommunityAt(uint256 _index) public view returns (IDonationCommunity community) {
        require(communities[_index] != IDonationCommunity(address(0)), "No such community exists");
        return communities[_index];
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
