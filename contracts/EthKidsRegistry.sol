pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract EthKidsRegistry is Ownable {

    uint256 public communityIndex = 0;
    mapping(uint256 => address) public communities;

    event CommunityRegistered(address communityAddress, uint256 index);

    function registerCommunity(address _communityAddress) onlyOwner public {
        communities[communityIndex] = _communityAddress;
        emit CommunityRegistered(_communityAddress, communityIndex);
        communityIndex++;
    }

    function removeCommunity(uint256 _index) onlyOwner public {
        communities[_index] = address(0);
    }

}
