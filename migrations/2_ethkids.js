var BondingVault = artifacts.require("BondingVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");

const empty_address = '0x0000000000000000000000000000000000000000';

module.exports = async function (deployer, network, accounts) {

    let bondingVaultInstance;
    let donationCommunityInstance;
    let registryInstance;

    let tokenName = "ChanceBY";
    let tokenSym = "CHANCE";

    console.log(`  === Deploying EthKids contracts to ${network}...`);
    await deployer.deploy(BondingVault, tokenName, tokenSym);
    bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    await deployer.deploy(DonationCommunity, bondingVaultInstance.address);
    donationCommunityInstance = await DonationCommunity.deployed();
    console.log('EthKids, DonationCommunity: NEW ' + donationCommunityInstance.address);

    console.log(`  Transferring ownership of the bondingVault to community...`);
    await bondingVaultInstance.transferOwnership(donationCommunityInstance.address);

    await deployer.deploy(EthKidsRegistry);
    registryInstance = await EthKidsRegistry.deployed();
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Registering community in the registry...`);
    await registryInstance.registerCommunity(donationCommunityInstance.address);

    console.log('DONE migration');
}