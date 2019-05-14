pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./utils/FractionalExponents.sol";
import "./CommunityToken.sol";

contract BondingVault is Secondary {
    using SafeMath for uint256;

    uint256 public constant AWARD_RATIO = 10; //X:1 ratio (e.g. for every 1 ETH sent to charity (!!!, not here), you get X tokens)

    CommunityToken public communityToken;
    FractionalExponents public exponentContract;

    event LogEthReceived(
        uint256 amount,
        address indexed account
    );
    event LogEthSent(
        uint256 amount,
        address indexed account
    );
    event LogTokenSell
    (
        address byWhom,
        uint256 price,
        uint256 amountOfEth
    );


    /**
    * @dev funding bondingVault and not receiving award is allowed
    **/
    function() external payable {
        emit LogEthReceived(msg.value, msg.sender);
    }

    constructor(string memory _tokenName, string memory _tokenSymbol) public {
        communityToken = new CommunityToken(_tokenName, _tokenSymbol);
        exponentContract = new FractionalExponents();
    }

    function fundWithAward(address payable _donator) public payable onlyPrimary {
        //calculate current 'buy' price for this donator
        (uint256 price, uint256 _tokenAmount) = myBuyPrice(msg.value, _donator);

        communityToken.mint(_donator, _tokenAmount);
        emit LogEthReceived(msg.value, _donator);
    }

    function sell(uint256 _amount, address payable _donator) public onlyPrimary {
        // calculate sell return
        (uint256 price, uint256 amountOfEth) = mySellPrice(_amount, _donator);

        communityToken.burnFrom(_donator, _amount);

        _donator.transfer(amountOfEth);
        emit LogEthSent(amountOfEth, _donator);
        emit LogTokenSell(_donator, price, amountOfEth);
    }

    /**
    * @dev Owner can withdraw the remaining ETH balance as long as amount of minted tokens is
    * less than 1 token (due to possible rounding leftovers)
    *
    */
    function sweepVault(address payable _operator) public onlyPrimary {
        require(communityToken.totalSupply() < 1 ether, 'Sweep available only if no minted tokens left');
        require(address(this).balance > 0, 'Vault is empty');
        _operator.transfer(address(this).balance);
        emit LogEthSent(address(this).balance, _operator);
    }

    function myBuyPrice(uint256 _ethAmount, address payable _donator) public onlyPrimary
    view returns (uint256 _finalPrice, uint256 _tokenAmount) {
        uint256 _tokenSupply = communityToken.totalSupply();
        uint256 _ethInVault = address(this).balance;
        if (_tokenSupply == 0) {
            //first donator in this community
            _tokenSupply = 1 ether;
            _ethInVault = 1 ether;
        }
        uint256 _tokenBalance = communityToken.balanceOf(_donator);
        if (_tokenBalance == 0) {
            //new donator, simulate 100% ownership
            _tokenBalance = _tokenSupply;
        }
        (uint256 price, uint256 amountOfEth) = applyBondingFormula(_ethAmount, _tokenBalance, _tokenSupply, _ethInVault);
        return (price, amountOfEth.mul(AWARD_RATIO));
    }

    function mySellPrice(uint256 _tokenAmount, address payable _donator) public onlyPrimary
    view returns (uint256 _finalPrice, uint256 _redeemableEth) {
        uint256 _tokenBalance = communityToken.balanceOf(_donator);
        require(_tokenAmount > 0 && _tokenBalance >= _tokenAmount, "Amount needs to be > 0 and tokenBalance >= amount to sell");

        uint256 _tokenSupply = communityToken.totalSupply();
        uint256 _ethInVault = address(this).balance;
        return applyBondingFormula(_tokenAmount, _tokenBalance, _tokenSupply, _ethInVault);
    }

    function applyBondingFormula(uint256 _tokenAmount, uint256 _tokenBalance, uint256 _tokenSupply, uint256 _ethInVault)
    internal view returns (uint256 _finalPrice, uint256 _redeemableEth) {
        // For EVM accuracy
        uint256 _multiplier = 10 ** 18;

        // a = (Sp.10^8)
        uint256 _portionE8 = (_tokenBalance.mul(10 ** 8).div(_tokenSupply));

        // b = a^1/10
        (uint256 _exponentResult, uint8 _precision) = exponentContract.power(_portionE8, 1, 1, 10);

        // b/8 * (funds backing curve / token supply)
        uint256 interimPrice = (_exponentResult.div(8)).mul(_ethInVault.mul(_multiplier).div(_tokenSupply)).div(_multiplier);

        // get final price (with multiplier)
        _finalPrice = (interimPrice.mul(_multiplier)).div(2 ** uint256(_precision));

        // redeemable ETH (without multiplier)
        _redeemableEth = _finalPrice.mul(_tokenAmount).div(_multiplier);
        return (_finalPrice, _redeemableEth);
    }

    function getCommunityToken() public view onlyPrimary returns (address) {
        return address(communityToken);
    }

}
