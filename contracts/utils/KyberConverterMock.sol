pragma solidity ^0.5.2;

import "../KyberConverter.sol";

contract KyberConverterMock is KyberConverter {

    constructor (KyberNetworkProxyInterface _kyberNetworkProxyContract, address _walletId, address _stableAddress)
    KyberConverter(_kyberNetworkProxyContract, _walletId, _stableAddress) public {}

    /**
    * @dev Simplified swap: converter with hold the 'source' ETH and send back 1:1 owned 'stable' token
    */
    function executeSwapMyETHToStable() public payable returns (uint256) {
        address payable destAddress = msg.sender;
        stableToken.transfer(msg.sender, msg.value);
        return msg.value;
    }

}