pragma solidity ^0.5.2;
import "./BondingVaultInterface.sol";

interface RegistryInterface {

    function getCurrencyConverter() external view returns (address);

    function getBondingVault() external view returns (BondingVaultInterface);

}