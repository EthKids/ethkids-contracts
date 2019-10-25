var BuyFormula = artifacts.require("GrowingInflationV1");
var LiquidationFormula = artifacts.require("ExponentialV1");
var BondingVault = artifacts.require("BondingVault");
var CharityVault = artifacts.require("CharityVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");
var KyberConverter = artifacts.require("KyberConverter");

const empty_address = '0x0000000000000000000000000000000000000000';

async function deployCommunity(deployer, tokenName, tokenSym, initialTokenMint, initialValueFunding) {

    await deployer.deploy(LiquidationFormula);
    const liquidationFormulaInstance = await LiquidationFormula.deployed();
    console.log('EthKids, LiquidationFormula: NEW ' + liquidationFormulaInstance.address);

    await deployer.deploy(BuyFormula);
    const buyFormulaInstance = await BuyFormula.deployed();
    console.log('EthKids, BuyFormula: NEW ' + buyFormulaInstance.address);

    await deployer.deploy(BondingVault, tokenName, tokenSym, buyFormulaInstance.address, liquidationFormulaInstance.address,
        initialTokenMint, {value: initialValueFunding});
    const bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    await deployer.deploy(DonationCommunity, empty_address, bondingVaultInstance.address);
    const communityInstance = await DonationCommunity.deployed();
    console.log('EthKids, DonationCommunity: NEW ' + communityInstance.address);

    console.log(`  Transferring ownership of the bondingVault to community...`);
    await bondingVaultInstance.transferPrimary(communityInstance.address);

    return communityInstance;

}

async function deployChanceBy(deployer) {
    const initialTokenMint = web3.utils.toWei("1", "ether"); //1 CHANCE, required for initial 'sell price' calculation
    const initialValueFunding = web3.utils.toWei("100", "finney"); //0.1 ETH, required for initial liquidation calculation
    return await deployCommunity(deployer, "ChanceBY", "CHANCE", initialTokenMint, initialValueFunding);
}

async function migrateCommunityCoreAndRegistry(deployer) {
    console.log(`  === New Registry...`);
    await deployer.deploy(EthKidsRegistry);
    let registry = await EthKidsRegistry.deployed();
    console.log('EthKids, EthKidsRegistry: NEW ' + registry.address);


    let currentCommunity = await DonationCommunity.at("0x87b98abd01219fc17300cfbce637774efd7e685b");
    let currentCharityVault = await CharityVault.at("0x883e895397614bbec6855ffa75aaf83bbd752acf");
    let currentBondingVault = await BondingVault.at("0xb2471fd32e44bfd2e09f0eb724e2022c7c966287");

    console.log(`  ===Deploying new ChanceBY community core...`);
    await deployer.deploy(DonationCommunity, currentCharityVault.address, currentBondingVault.address);
    let chanceByCommunityInstance = await DonationCommunity.deployed();
    console.log('EthKids, DonationCommunity: NEW ' + chanceByCommunityInstance.address);

    console.log(`  ===Re-pointing both vault's to new owner (new community instance)...`);
    await currentCommunity.transferOwnership(chanceByCommunityInstance.address);


    console.log(`  Registering community in the registry...`);
    await registry.registerCommunity(chanceByCommunityInstance.address);

    console.log('DONE migration');

}

function getKyberForNetwork(network, accounts) {
    if (network == 'development') {
        return {
            kyberNetworkAddress: empty_address,
            feeWallet: empty_address,
            stableToken: empty_address,
        }
    } else if (network == 'rinkeby') {
        return {
            kyberNetworkAddress: '0xF77eC7Ed5f5B9a5aee4cfa6FFCaC6A4C315BaC76',
            feeWallet: empty_address,
            stableToken: '0x6FA355a7b6bD2D6bD8b927C489221BFBb6f1D7B2', //KNC
        }
    } else if (network == 'ropsten') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: empty_address,
            stableToken: '0xaD6D458402F60fD3Bd25163575031ACDce07538D', //DAI
        }
    } else if (network == 'live') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: '0xDdC0E4931936d9F590Ccb29f7f4758751479d0A8',
            stableToken: '0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359', //DAI
        }
    }
}

module.exports = async function (deployer, network, accounts) {

    let chanceByCommunityInstance;
    let registryInstance;
    let kyberConverterInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);

    await deployer.deploy(EthKidsRegistry);
    registryInstance = await EthKidsRegistry.deployed();
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Deploying dedicated Kyber converter...`);
    const {kyberNetworkAddress, feeWallet, stableToken} = getKyberForNetwork(network, accounts)
    kyberConverterInstance = await deployer.deploy(KyberConverter, kyberNetworkAddress, feeWallet, stableToken);
    console.log('EthKids, KyberConverter: NEW ' + kyberConverterInstance.address);

    console.log(`  Registering converter in the registry...`);
    await registryInstance.registerCurrencyConverter(kyberConverterInstance.address);

    chanceByCommunityInstance = await deployChanceBy(deployer);
    console.log(`  Registering community in the registry...`);
    await chanceByCommunityInstance.addSigner(registryInstance.address);
    await registryInstance.registerCommunity(chanceByCommunityInstance.address);

    console.log('DONE migration');
}