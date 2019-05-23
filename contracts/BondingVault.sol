pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CommunityToken.sol";

/**
 * @title BondingVault
 * @dev Vault which holds (a part) of the donations and mints the tokens to the donators in return.
 * Actual funding and liquidation calls come from the community contract.
 * The logic of price (both award and liquidation) calculation is delegated to 2 corresponding formulas
 *
 */
contract BondingVault is Secondary {
    using SafeMath for uint256;

    CommunityToken public communityToken;

    BuyFormula public buyFormula;
    LiquidationFormula public liquidationFormula;

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
    * @dev funding bondingVault and not receiving tokens back is allowed
    **/
    function() external payable {
        emit LogEthReceived(msg.value, msg.sender);
    }

    constructor(string memory _tokenName, string memory _tokenSymbol, address _buyFormulaAddress, address _liquidationFormulaAddress, uint256 _initialMint)
    public payable{
        communityToken = new CommunityToken(_tokenName, _tokenSymbol);
        communityToken.mint(msg.sender, _initialMint);
        buyFormula = BuyFormula(_buyFormulaAddress);
        liquidationFormula = LiquidationFormula(_liquidationFormulaAddress);
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
        //1 initially minted + 1 possible rounding corrections
        require(communityToken.totalSupply() < 2 ether, 'Sweep available only if no minted tokens left');
        require(address(this).balance > 0, 'Vault is empty');
        _operator.transfer(address(this).balance);
        emit LogEthSent(address(this).balance, _operator);
    }

    function myBuyPrice(uint256 _ethAmount, address payable _donator) public onlyPrimary
    view returns (uint256 finalPrice, uint256 tokenAmount) {
        uint256 _tokenSupply = communityToken.totalSupply();
        uint256 _ethInVault = address(this).balance;
        uint256 _tokenBalance = communityToken.balanceOf(_donator);
        return buyFormula.applyFormula(_ethAmount, _tokenBalance, _tokenSupply, _ethInVault);
    }

    function mySellPrice(uint256 _tokenAmount, address payable _donator) public onlyPrimary
    view returns (uint256 finalPrice, uint256 redeemableEth) {
        uint256 _tokenBalance = communityToken.balanceOf(_donator);
        require(_tokenAmount > 0 && _tokenBalance >= _tokenAmount, "Amount needs to be > 0 and tokenBalance >= amount to sell");

        uint256 _tokenSupply = communityToken.totalSupply();
        uint256 _ethInVault = address(this).balance;
        return liquidationFormula.applyFormula(_tokenAmount, _tokenBalance, _tokenSupply, _ethInVault);
    }

    function getCommunityToken() public view onlyPrimary returns (address) {
        return address(communityToken);
    }

    function setBuyFormula(address _newBuyFormula) public onlyPrimary {
        buyFormula = BuyFormula(_newBuyFormula);
    }

    function setSellFormula(address _newSellFormula) public onlyPrimary {
        liquidationFormula = LiquidationFormula(_newSellFormula);
    }

}

interface BuyFormula {

    function applyFormula(uint256 _ethAmount, uint256 _tokenBalance, uint256 _tokenSupply, uint256 _ethInVault)
    external view returns (uint256 _finalPrice, uint256 _tokenAmount);

}

interface LiquidationFormula {

    function applyFormula(uint256 _tokenAmount, uint256 _tokenBalance, uint256 _tokenSupply, uint256 _ethInVault)
    external view returns (uint256 _finalPrice, uint256 _redeemableEth);

}
