pragma solidity ^0.5.2;

interface BondingVaultInterface {

    function fundWithAward(address payable _donor) external payable;

    function sell(uint256 _amount, address payable _donor) external;

    function getEthKidsToken() external view returns (address);

    function calculateReward(uint256 _ethAmount, address payable _donor, uint256 _vaultBalance) external view returns (uint256 _tokenAmount);

    function calculateReturn(uint256 _tokenAmount, address payable _donor) external view returns (uint256 _returnEth);

    function sweepVault(address payable _operator) external;

    function transferPrimary(address recipient) external;

    function addWhitelisted(address account) external;

    function removeWhitelisted(address account) external;

}