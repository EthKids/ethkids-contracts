pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CharityVault.sol";

/**
 * @title DonationCommunity
 * @dev Main contract for a charity donation community.
 * Creates a corresponding vault for charity and expects a 'smart' bonding vault to be provided
 */
contract DonationCommunity is SignerRole {
    using SafeMath for uint256;

    uint256 public constant CHARITY_DISTRIBUTION = 90; //%, the rest funds bonding curve

    CharityVault public charityVault;
    BondingVaultInterface public bondingVault;

    event LogDonationReceived
    (
        address from,
        uint256 amount
    );
    event LogTokensSold
    (
        address from,
        uint256 amount
    );
    event LogPassToCharity
    (
        address by,
        address intermediary,
        uint256 amount,
        string ipfsHash
    );

    /**
    * @dev Default fallback function, just deposits funds to the charity
    */
    function() external payable {
        address(charityVault).transfer(msg.value);
    }

    /**
    * @dev Constructor, used for initial creation and migrations
    * @dev If migrating make sure (!!) both vaults' owners will be pointing to 'this' instance
    * @param _charityVaultAddress (Optional) address of the Charity Vault
    * @param _bondingVaultAddress Address of the Bonding Vault
    */
    constructor (address payable _charityVaultAddress, address payable _bondingVaultAddress) public {
        require(_bondingVaultAddress != address(0));
        if (_charityVaultAddress == address(0)) {
            charityVault = new CharityVault();
        } else {
            charityVault = CharityVault(_charityVaultAddress);
        }
        bondingVault = BondingVaultInterface(_bondingVaultAddress);
    }

    function donate() public payable {
        donateDelegated(msg.sender);
    }

    /**
    * @dev Donate funds on behalf of someone else.
    * Primary use is to pass the actual donator when the caller is a proxy, like KyberConverter
    * @param _donator address that will be recorded as a donator and will receive the community tokens
    **/
    function donateDelegated(address payable _donator) public payable {
        require(msg.value > 0, "Must include some ETH to donate");

        uint256 _multiplier = 100;
        uint256 _charityAllocation = (msg.value).mul(CHARITY_DISTRIBUTION).div(_multiplier);
        uint256 _bondingAllocation = msg.value.sub(_charityAllocation);
        charityVault.deposit.value(_charityAllocation)(_donator);

        bondingVault.fundWithAward.value(_bondingAllocation)(_donator);

        emit LogDonationReceived(_donator, msg.value);
    }

    function myBuy(uint256 _ethAmount) public view returns (uint256 finalPrice, uint256 tokenAmount) {
        return bondingVault.myBuyPrice(_ethAmount, msg.sender);
    }

    function myReturn(uint256 _sellAmount) public view returns (uint256 price, uint256 amountOfEth) {
        return returnForAddress(_sellAmount, msg.sender);
    }

    function returnForAddress(uint256 _sellAmount, address payable _requestedAddress) public view returns (uint256 price, uint256 amountOfEth) {
        return bondingVault.mySellPrice(_sellAmount, _requestedAddress);
    }

    function sell(uint256 _amount) public {
        bondingVault.sell(_amount, msg.sender);
        emit LogTokensSold(msg.sender, _amount);
    }

    function sweepBondingVault() public onlySigner {
        bondingVault.sweepVault(msg.sender);
    }

    function passToCharity(uint256 _amount, address payable _intermediary, string memory _ipfsHash) public onlySigner {
        require(_intermediary != address(0));
        charityVault.withdraw(_intermediary, _amount);
        emit LogPassToCharity(msg.sender, _intermediary, _amount, _ipfsHash);
    }

    function getCommunityToken() public view returns (address) {
        return bondingVault.getCommunityToken();
    }

    //Migrations

    function replaceBuyFormula(address _newBuyFormula) public onlySigner {
        bondingVault.setBuyFormula(_newBuyFormula);
    }

    function replaceSellFormula(address _newSellFormula) public onlySigner {
        bondingVault.setSellFormula(_newSellFormula);
    }

    function replaceBondingVault(address _newBondingVault) public onlySigner {
        bondingVault = BondingVaultInterface(_newBondingVault);
    }

    function replaceCharityVault() public onlySigner {
        charityVault = new CharityVault();
    }

    /**
    * @dev If this community migrates but leaving existing vaults,
    * this method must be called to re-point vaults to new community as the owner
    */
    function transferOwnership(address newPrimary) public onlySigner {
        charityVault.transferPrimary(newPrimary);
        bondingVault.transferPrimary(newPrimary);
    }


}

interface BondingVaultInterface {

    function fundWithAward(address payable _donator) external payable;

    function sell(uint256 _amount, address payable _donator) external;

    function getCommunityToken() external view returns (address);

    function myBuyPrice(uint256 _ethAmount, address payable _donator) external view returns (uint256 _finalPrice, uint256 _tokenAmount);

    function mySellPrice(uint256 _tokenAmount, address payable _donator) external view returns (uint256 _finalPrice, uint256 _redeemableEth);

    function sweepVault(address payable _operator) external;

    function setBuyFormula(address _newBuyFormula) external;

    function setSellFormula(address _newSellFormula) external;

    function transferPrimary(address recipient) external;

}
