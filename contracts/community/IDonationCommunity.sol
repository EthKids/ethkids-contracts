pragma solidity ^0.5.2;

interface IDonationCommunity {

    function donateDelegated(address payable _donator) external payable;

    function name() external view returns (string memory);
}