pragma solidity ^0.5.8;

interface YieldVaultInterface {

    function withdraw(address _token, address _atoken, uint _amount) external;

    function withdrawAllDai() external;

    function addWhitelisted(address account) external;

    function removeWhitelisted(address account) external;

}
