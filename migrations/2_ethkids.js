var BuyFormula = artifacts.require("GrowingInflationV1");
var LiquidationFormula = artifacts.require("ExponentialV1");
var BondingVault = artifacts.require("BondingVault");
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

async function migrateCommunityCore(deployer, registry, community) {
    let currentCharityVault = await community.charityVault;
    let currentBondingVault = await community.bondingVault;
    await registry.removeCommunity(0);

}

function getKyberForNetwork(network, accounts) {
    if (network == 'development') {
        return {
            kyberNetworkAddress: empty_address,
            feeWallet: empty_address,
        }
    } else if (network == 'rinkeby') {
        return {
            kyberNetworkAddress: '0xF77eC7Ed5f5B9a5aee4cfa6FFCaC6A4C315BaC76',
            feeWallet: empty_address,
        }
    } else if (network == 'ropsten') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: empty_address,
        }
    } else if (network == 'live') {
        return {
            kyberNetworkAddress: '0x818E6FECD516Ecc3849DAf6845e3EC868087B755',
            feeWallet: '0xDdC0E4931936d9F590Ccb29f7f4758751479d0A8',
        }
    }
}

module.exports = async function (deployer, network, accounts) {

    let chanceByCommunityInstance;
    let registryInstance;
    let kyberConverterInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);

    chanceByCommunityInstance = await deployChanceBy(deployer);

    await deployer.deploy(EthKidsRegistry);
    registryInstance = await EthKidsRegistry.deployed();
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Registering community in the registry...`);
    await registryInstance.registerCommunity(chanceByCommunityInstance.address);

    console.log(`  Deploying dedicated Kyber converter...`);
    const {kyberNetworkAddress, feeWallet} = getKyberForNetwork(network, accounts)
    kyberConverterInstance = await deployer.deploy(KyberConverter, kyberNetworkAddress, feeWallet);
    console.log('EthKids, KyberConverter: NEW ' + kyberConverterInstance.address);

    console.log('DONE migration');
}