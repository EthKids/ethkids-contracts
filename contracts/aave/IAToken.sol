pragma solidity ^0.5.8;

interface IAToken {

    function balanceOf(address _user) external view returns (uint256);

    function redeem(uint256 _amount) external;

    function principalBalanceOf(address _user) external view returns (uint256);

    function getInterestRedirectionAddress(address _user) external view returns (address);

    function allowInterestRedirectionTo(address _to) external;

    function redirectInterestStream(address _to) external;

    function isTransferAllowed(address _user, uint256 _amount) external view returns (bool);

}