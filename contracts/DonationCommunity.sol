pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CharityVault.sol";

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

    constructor (address _bondingVaultAddress) public {
        require(_bondingVaultAddress != address(0));
        charityVault = new CharityVault();
        bondingVault = BondingVaultInterface(_bondingVaultAddress);
    }

    function donate() public payable {
        require(msg.value > 0, "Must include some ETH to donate");

        uint256 _multiplier = 100;
        uint256 _charityAllocation = (msg.value).mul(CHARITY_DISTRIBUTION).div(_multiplier);
        uint256 _bondingAllocation = msg.value.sub(_charityAllocation);
        charityVault.deposit.value(_charityAllocation)(msg.sender);

        bondingVault.fundWithAward.value(_bondingAllocation)(msg.sender);

        emit LogDonationReceived(msg.sender, msg.value);
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


}

interface BondingVaultInterface {

    function fundWithAward(address payable _donator) external payable;

    function sell(uint256 _amount, address payable _donator) external;

    function getCommunityToken() external view returns (address);

    function mySellPrice(uint256 _tokenAmount, address payable _donator) external view returns (uint256 _finalPrice, uint256 _redeemableEth);

    function sweepVault(address payable _operator) external;

}
