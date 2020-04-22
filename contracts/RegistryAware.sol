pragma solidity ^0.5.2;

import "./RegistryInterface.sol";

interface RegistryAware {

    function setRegistry(address _registry) external;

    function getRegistry() external view returns (RegistryInterface);
}