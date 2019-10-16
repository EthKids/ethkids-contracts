pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../../smart-contracts/contracts/KyberNetworkProxyInterface.sol";
import "../../smart-contracts/contracts/ERC20Interface.sol";

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
     * @dev Swap the user's ERC20 token to ETH and donates to the community.
     * Note: requires 'approve' srcToken first!
     * @param srcToken source token contract address
     * @param srcQty amount of source tokens
     * @param maxDestAmount address to send swapped tokens to
     * @param community address of the donation community
     */
    function executeSwapAndDonate(
        ERC20 srcToken,
        uint srcQty,
        uint maxDestAmount,
        IDonationCommunity community
    ) public {
        uint minConversionRate;

        // Save prev src token balance
        uint256 prevSrcBalance = srcToken.balanceOf(address(this));

        // Check that the token transferFrom has succeeded
        require(srcToken.transferFrom(msg.sender, address(this), srcQty));

        // Mitigate ERC20 Approve front-running attack, by initially setting
        // allowance to 0
        require(srcToken.approve(address(kyberNetworkProxyContract), 0));

        // Set the spender's token allowance to tokenQty
        require(srcToken.approve(address(kyberNetworkProxyContract), srcQty));

        // Get the minimum conversion rate
        (minConversionRate,) = kyberNetworkProxyContract.getExpectedRate(srcToken, ETH_TOKEN_ADDRESS, srcQty);

        // Swap the ERC20 token and send to 'this' contract address
        bytes memory hint;
        uint256 amount = kyberNetworkProxyContract.tradeWithHint(
            srcToken,
            srcQty,
            ETH_TOKEN_ADDRESS,
            address(this),
            maxDestAmount,
            minConversionRate,
            walletId,
            hint
        );

        // Clean kyber to use _srcTokens on belhalf of this contract
        require(
            srcToken.approve(address(kyberNetworkProxyContract), 0),
            "Could not clear approval of kyber to use srcToken on behalf of this contract"
        );

        // Return the change of src token
        uint256 change = srcToken.balanceOf(address(this)).sub(prevSrcBalance);

        if (change > 0) {
            require(
                srcToken.transfer(msg.sender, change),
                "Could not transfer change to sender"
            );
        }

        // donate ETH to the community
        community.donateDelegated.value(amount)(msg.sender);


        // Log the event
        emit Swap(msg.sender, srcToken, ETH_TOKEN_ADDRESS);
    }

    /**
     * @dev Recovery for change funds
     */
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Insufficient funds to withdraw");
        msg.sender.transfer(address(this).balance);
    }

}

interface IDonationCommunity {

    function donateDelegated(address payable _donator) external payable;
}