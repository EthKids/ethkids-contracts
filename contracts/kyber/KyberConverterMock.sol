pragma solidity ^0.5.2;

import "./KyberConverter.sol";

/**
 * @title KyberConverterMock
 * @dev The dummy mostly for test to mock the actual Kyber swap
 * It swaps the ETH to ERC 1:1, keeping the ETH and giving back owned ERC
 *
 */
contract KyberConverterMock is KyberConverter {

    constructor (KyberNetworkProxyInterface _kyberNetworkProxyContract, address _walletId)
    KyberConverter(_kyberNetworkProxyContract, _walletId) public {}

    /**
    * @dev Simplified swap: converter with hold the 'source' ETH and send back 1:1 owned erc20 token
    */
    function executeSwapMyETHToERC(address _ercAddress) public payable returns (uint256) {
        address payable destAddress = msg.sender;
        ERC20 ercToken = ERC20(_ercAddress);
        ercToken.transfer(msg.sender, msg.value);
        return msg.value;
    }

}