pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CommunityToken.sol";

/**
 * @title BondingVault
 * @dev Vault which holds (a part) of the donations and mints the tokens to the donors in return.
 * Actual funding and liquidation calls come from the community contract.
 * The logic of price (both award and liquidation) calculation is delegated to 2 corresponding formulas
 *
 */
contract BondingVault is Secondary {
    using SafeMath for uint256;

    CommunityToken public communityToken;

    BondingCurveFormula public bondingCurveFormula;

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
        uint256 amountOfEth
    );


    /**
    * @dev funding bondingVault and not receiving tokens back is allowed
    **/
    function() external payable {
        emit LogEthReceived(msg.value, msg.sender);
    }

    constructor(string memory _tokenName, string memory _tokenSymbol, address _formulaAddress, uint256 _initialMint)
    public payable{
        communityToken = new CommunityToken(_tokenName, _tokenSymbol);
        communityToken.mint(msg.sender, _initialMint);
        bondingCurveFormula = BondingCurveFormula(_formulaAddress);
    }

    function fundWithAward(address payable _donor) public payable onlyPrimary {
        uint256 _tokenAmount = calculateReward(msg.value, _donor);

        communityToken.mint(_donor, _tokenAmount);
        emit LogEthReceived(msg.value, _donor);
    }

    function sell(uint256 _amount, address payable _donor) public onlyPrimary {
        uint256 amountOfEth = calculateReturn(_amount, _donor);
        require(address(this).balance > amountOfEth, 'Insufficient funds in the vault');
        communityToken.burnFrom(_donor, _amount);

        _donor.transfer(amountOfEth);
        emit LogEthSent(amountOfEth, _donor);
        emit LogTokenSell(_donor, amountOfEth);
    }

    /**
    * @dev Recovery in case of emergency
    *
    */
    function sweepVault(address payable _operator) public onlyPrimary {
        require(address(this).balance > 0, 'Vault is empty');
        _operator.transfer(address(this).balance);
        emit LogEthSent(address(this).balance, _operator);
    }

    function calculateReward(uint256 _ethAmount, address payable _donor) public onlyPrimary
    view returns (uint256 tokenAmount) {
        uint256 _tokenSupply = communityToken.totalSupply();
        uint256 _tokenBalance = communityToken.balanceOf(_donor);
        if (_tokenBalance == 0) {
            //first donation, offer best market price
            _tokenBalance = communityToken.smallestHolding();
        }
        return bondingCurveFormula.calculatePurchaseReturn(_tokenSupply, _tokenBalance, _ethAmount);
    }

    function calculateReturn(uint256 _tokenAmount, address payable _donor) public onlyPrimary
    view returns (uint256 returnEth) {
        uint256 _tokenBalance = communityToken.balanceOf(_donor);
        require(_tokenAmount > 0 && _tokenBalance >= _tokenAmount, "Amount needs to be > 0 and tokenBalance >= amount to sell");

        uint256 _tokenSupply = communityToken.totalSupply();
        return bondingCurveFormula.calculateSaleReturn(_tokenSupply, _tokenBalance, _tokenAmount);
    }

    function getCommunityToken() public view onlyPrimary returns (address) {
        return address(communityToken);
    }

    function setFormula(address _newFormula) public onlyPrimary {
        bondingCurveFormula = BondingCurveFormula(_newFormula);
    }

}

interface BondingCurveFormula {

    function calculatePurchaseReturn(uint256 _supply, uint256 _currentHoldings, uint256 _depositAmount) external view returns (uint256);

    function calculateSaleReturn(uint256 _supply, uint256 _currentHoldings, uint256 _sellAmount) external view returns (uint256);

}
