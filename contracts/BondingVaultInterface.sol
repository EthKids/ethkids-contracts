pragma solidity ^0.5.2;

interface BondingVaultInterface {

    function fundWithReward(address payable _donor) external payable;

    function getEthKidsToken() external view returns (address);

    function calculateReward(uint256 _ethAmount) external view returns (uint256 _tokenAmount);

    function calculateReturn(uint256 _tokenAmount) external view returns (uint256 _returnEth);

    function sweepVault(address payable _operator) external;

    function addWhitelisted(address account) external;

    function removeWhitelisted(address account) external;

}