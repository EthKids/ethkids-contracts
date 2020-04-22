pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/access/roles/SignerRole.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./CharityVault.sol";
import "./RegistryInterface.sol";

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

    RegistryInterface public registry;

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
    * @dev Default fallback function, just deposits funds to the community
    */
    function() external payable {
        ((address) (bondingVault)).call.value(msg.value)("");
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

    function setRegistry(address _registry) public onlySigner {
        registry = (RegistryInterface)(_registry);
        charityVault.setCurrencyConverter(registry.getCurrencyConverter());
    }

    function allocate(uint256 donation) internal view returns (uint256 _charityAllocation, uint256 _bondingAllocation) {
        uint256 _multiplier = 100;
        uint256 _charityAllocation = (donation).mul(CHARITY_DISTRIBUTION).div(_multiplier);
        uint256 _bondingAllocation = donation.sub(_charityAllocation);
        return (_charityAllocation, _bondingAllocation);
    }

    function donate() public payable {
        donateDelegated(msg.sender);
    }

    /**
    * @dev Donate funds on behalf of someone else.
    * Primary use is to pass the actual donor when the caller is a proxy, like KyberConverter
    * @param _donor address that will be recorded as a donor and will receive the community tokens
    **/
    function donateDelegated(address payable _donor) public payable {
        require(msg.value > 0, "Must include some ETH to donate");

        (uint256 _charityAllocation, uint256  _bondingAllocation) = allocate(msg.value);
        charityVault.deposit.value(_charityAllocation)(_donor);

        bondingVault.fundWithAward.value(_bondingAllocation)(_donor);

        emit LogDonationReceived(_donor, msg.value);
    }

    function myReward(uint256 _ethAmount) public view returns (uint256 tokenAmount) {
        (uint256 _charityAllocation, uint256  _bondingAllocation) = allocate(_ethAmount);
        return bondingVault.calculateReward(_bondingAllocation, msg.sender, _bondingAllocation.add(address(bondingVault).balance));
    }

    function myReturn(uint256 _sellAmount) public view returns (uint256 amountOfEth) {
        return returnForAddress(_sellAmount, msg.sender);
    }

    function returnForAddress(uint256 _sellAmount, address payable _requestedAddress) public view returns (uint256 amountOfEth) {
        return bondingVault.calculateReturn(_sellAmount, _requestedAddress);
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

    function replaceFormula(address _newFormula) public onlySigner {
        bondingVault.setFormula(_newFormula);
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

    function fundWithAward(address payable _donor) external payable;

    function sell(uint256 _amount, address payable _donor) external;

    function getCommunityToken() external view returns (address);

    function calculateReward(uint256 _ethAmount, address payable _donor, uint256 _vaultBalance) external view returns (uint256 _tokenAmount);

    function calculateReturn(uint256 _tokenAmount, address payable _donor) external view returns (uint256 _returnEth);

    function sweepVault(address payable _operator) external;

    function setFormula(address _newFormula) external;

    function transferPrimary(address recipient) external;

}
