pragma solidity ^0.5.2;
import "./BondingVaultInterface.sol";
import "./YieldVaultInterface.sol";

interface RegistryInterface {

    function getCurrencyConverter() external view returns (address);

    function getBondingVault() external view returns (BondingVaultInterface);

    function yieldVault() external view returns (YieldVaultInterface);

    function getCharityVaults() external view returns (address[] memory);

    function communityCount() external view returns (uint256);

}