pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "openzeppelin-solidity/contracts/utils/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/Address.sol";
import "./RegistryInterface.sol";
import "./RegistryAware.sol";
import "./BondingVaultInterface.sol";
import "./YieldVaultInterface.sol";
import "./community/IDonationCommunity.sol";

/**
 * @title EthKidsRegistry
 * @dev Holds the list of the communities' addresses
 */
contract EthKidsRegistry is RegistryInterface, SignerRole {

    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    BondingVaultInterface public bondingVault;
    YieldVaultInterface public yieldVault;
    EnumerableSet.AddressSet private communities;
    address public currencyConverter;

    event CommunityRegistered(address communityAddress);

    /**
    * @dev Default fallback function, just deposits funds to the community
    */
    function() external payable {
        address(bondingVault).toPayable().transfer(msg.value);
    }

    constructor (address payable _bondingVaultAddress, address _yieldVault) public {
        require(_bondingVaultAddress != address(0));
        bondingVault = BondingVaultInterface(_bondingVaultAddress);
        require(_yieldVault != address(0));
        yieldVault = YieldVaultInterface(_yieldVault);
    }

    function registerCommunity(address _communityAddress) onlySigner public {
        require(communities.add(_communityAddress), 'This community is already present!');
        ((RegistryAware)(_communityAddress)).setRegistry(address(this));
        bondingVault.addWhitelisted(_communityAddress);
        yieldVault.addWhitelisted(_communityAddress);
        emit CommunityRegistered(_communityAddress);
    }

    function registerCurrencyConverter(address _currencyConverter) onlySigner public {
        currencyConverter = _currencyConverter;
    }

    function removeCommunity(address _address) onlySigner public {
        bondingVault.removeWhitelisted(_address);
        yieldVault.removeWhitelisted(_address);
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

    function distributeYieldVault(address _token, address _atoken, uint _amount) public onlySigner {
        yieldVault.withdraw(_token, _atoken, _amount);
    }

    function getCurrencyConverter() public view returns (address) {
        return currencyConverter;
    }

    function getBondingVault() public view returns (BondingVaultInterface) {
        return bondingVault;
    }

    function getCharityVaults() public view returns (address[] memory) {
        address[] memory result = communities.enumerate();
        for (uint8 i = 0; i < result.length; i++) {
            result[i] = IDonationCommunity(result[i]).charityVault();
        }
        return result;
    }


}
