pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./KyberNetworkProxyInterface.sol";
import "../ERC20.sol";
import "../community/IDonationCommunity.sol";

contract KyberConverter is Ownable {
    using SafeMath for uint256;
    ERC20 constant internal ETH_TOKEN_ADDRESS = ERC20(0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee);

    KyberNetworkProxyInterface public kyberNetworkProxyContract;
    address public walletId;

    // Events
    event Swap(address indexed sender, ERC20 srcToken, ERC20 destToken);

    /**
     * @dev Payable fallback to receive ETH while converting
     **/
    function() external payable {
    }

    constructor (KyberNetworkProxyInterface _kyberNetworkProxyContract, address _walletId) public {
        kyberNetworkProxyContract = _kyberNetworkProxyContract;
        walletId = _walletId;
    }

    /**
     * @dev Gets the conversion rate for the destToken given the srcQty.
     * @param srcToken source token contract address
     * @param srcQty amount of source tokens
     * @param destToken destination token contract address
     */
    function getConversionRates(
        ERC20 srcToken,
        uint srcQty,
        ERC20 destToken
    ) public
    view
    returns (uint, uint)
    {
        return kyberNetworkProxyContract.getExpectedRate(srcToken, destToken, srcQty);
    }

    /**
     * @dev Swap the user's ERC20 token to ETH
     * Note: requires 'approve' srcToken first!
     * @param srcToken source token contract address
     * @param srcQty amount of source tokens
     */
    function executeSwapMyERCToETH(ERC20 srcToken, uint srcQty) public {
        swapERCToETH(srcToken, srcQty, msg.sender);
        emit Swap(msg.sender, srcToken, ETH_TOKEN_ADDRESS);
    }


    /**
     * @dev Swap the user's ERC20 token to ETH and donates to the community.
     * Note: requires 'approve' srcToken first!
     * @param srcToken source token contract address
     * @param srcQty amount of source tokens
     * @param community address of the donation community
     */
    function executeSwapAndDonate(ERC20 srcToken, uint srcQty, IDonationCommunity community) public {
        swapERCToETH(srcToken, srcQty, address(this));
        // donate ETH to the community
        community.donateDelegated.value(address(this).balance)(msg.sender);
        emit Swap(msg.sender, srcToken, ETH_TOKEN_ADDRESS);
    }

    function swapERCToETH(ERC20 srcToken, uint srcQty, address destAddress) internal {
        uint minConversionRate;

        // Check that the token transferFrom has succeeded
        require(srcToken.transferFrom(msg.sender, address(this), srcQty));

        // Set the spender's token allowance to tokenQty
        require(srcToken.approve(address(kyberNetworkProxyContract), srcQty));

        // Get the minimum conversion rate
        (minConversionRate,) = kyberNetworkProxyContract.getExpectedRate(srcToken, ETH_TOKEN_ADDRESS, srcQty);
        // -5% max
        minConversionRate = minConversionRate.mul(95).div(100);
        // +5% max
        uint maxDestAmount = srcQty.mul(minConversionRate).mul(105).div(100);

        // Swap the ERC20 token and send to 'this' contract address
        bytes memory hint;
        uint256 amount = kyberNetworkProxyContract.tradeWithHint(
            srcToken,
            srcQty,
            ETH_TOKEN_ADDRESS,
            destAddress,
            maxDestAmount,
            minConversionRate,
            walletId,
            hint
        );

        // Return the change of src token
        uint256 change = srcToken.balanceOf(address(this));

        if (change > 0) {
            require(
                srcToken.transfer(msg.sender, change),
                "Could not transfer change to sender"
            );
        }
    }

    function executeSwapMyETHToERC(address _ercAddress) public payable returns (uint256) {
        uint minConversionRate;
        uint srcQty = msg.value;
        address destAddress = msg.sender;
        ERC20 ercToken = ERC20(_ercAddress);

        // Get the minimum conversion rate
        (minConversionRate,) = kyberNetworkProxyContract.getExpectedRate(ETH_TOKEN_ADDRESS, ercToken, srcQty);

        uint maxDestAmount = srcQty.mul(minConversionRate).mul(105).div(100);
        // 5%

        // Swap the ERC20 token and send to destAddress
        bytes memory hint;
        uint256 amount = kyberNetworkProxyContract.tradeWithHint.value(srcQty)(
            ETH_TOKEN_ADDRESS,
            srcQty,
            ercToken,
            destAddress,
            maxDestAmount,
            minConversionRate,
            walletId,
            hint
        );
        // Return the change of ETH if any
        uint256 change = address(this).balance;
        if (change > 0) {
            address(msg.sender).transfer(change);
        }
        // Log the event
        emit Swap(msg.sender, ETH_TOKEN_ADDRESS, ercToken);

        return amount;
    }

    /**
     * @dev Recovery for the remaining change
     */
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Insufficient funds to withdraw");
        msg.sender.transfer(address(this).balance);
    }

}