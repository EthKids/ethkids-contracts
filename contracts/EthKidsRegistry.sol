pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "./RegistryInterface.sol";

/**
 * @title EthKidsRegistry
 * @dev Holds the list of the communities' addresses
 */
contract EthKidsRegistry is RegistryInterface, SignerRole {

    uint256 public communityIndex = 0;
    mapping(uint256 => address) public communities;
    address public currencyConverter;

    event CommunityRegistered(address communityAddress, uint256 index);

    function registerCommunity(address _communityAddress) onlySigner public {
        registerCommunityAt(_communityAddress, communityIndex);
        communityIndex++;
    }

    /**
    * @dev Make sure the community has address(this) as one of _signers in order to set registry instance
    **/
    function registerCommunityAt(address _communityAddress, uint256 index) onlySigner public {
        communities[index] = _communityAddress;
        ((RegistryAware)(_communityAddress)).setRegistry(address(this));
        emit CommunityRegistered(_communityAddress, index);
    }

    function registerCurrencyConverter(address _currencyConverter) onlySigner public {
        currencyConverter = _currencyConverter;
    }

    function removeCommunity(uint256 _index) onlySigner public {
        communities[_index] = address(0);
    }

    function getCommunityAt(uint256 _index) public view returns (address community) {
        require(communities[_index] != address(0), "No such community exists");
        return communities[_index];
    }

    function getCurrencyConverter() public view returns (address) {
        return currencyConverter;
    }

}

interface RegistryAware {

    function setRegistry(address _registry) external;

}
