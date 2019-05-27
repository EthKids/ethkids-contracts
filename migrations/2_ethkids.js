var BuyFormula = artifacts.require("GrowingInflationV1");
var LiquidationFormula = artifacts.require("ExponentialV1");
var BondingVault = artifacts.require("BondingVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");

const empty_address = '0x0000000000000000000000000000000000000000';

async function deployCommunity(deployer, tokenName, tokenSym, initialTokenMint, initialValueFunding) {
    let buyFormulaInstance;
    let liquidationFormulaInstance;
    let bondingVaultInstance;

    await deployer.deploy(LiquidationFormula);
    liquidationFormulaInstance = await LiquidationFormula.deployed();
    console.log('EthKids, LiquidationFormula: NEW ' + liquidationFormulaInstance.address);

    await deployer.deploy(BuyFormula);
    buyFormulaInstance = await BuyFormula.deployed();
    console.log('EthKids, BuyFormula: NEW ' + buyFormulaInstance.address);

    await deployer.deploy(BondingVault, tokenName, tokenSym, buyFormulaInstance.address, liquidationFormulaInstance.address,
        initialTokenMint, {value: initialValueFunding});
    bondingVaultInstance = await BondingVault.deployed();
    console.log('EthKids, BondingVault: NEW ' + bondingVaultInstance.address);

    await deployer.deploy(DonationCommunity, bondingVaultInstance.address);
    chanceByCommunityInstance = await DonationCommunity.deployed();
    console.log('EthKids, DonationCommunity: NEW ' + chanceByCommunityInstance.address);

    console.log(`  Transferring ownership of the bondingVault to community...`);
    await bondingVaultInstance.transferPrimary(chanceByCommunityInstance.address);

    return chanceByCommunityInstance;

}

module.exports = async function (deployer, network, accounts) {

    let chanceByCommunityInstance;
    let registryInstance;

    console.log(`  === Deploying EthKids contracts to ${network}...`);

    const initialTokenMint = web3.utils.toWei("1", "ether"); //1 CHANCE, required for initial 'sell price' calculation
    const initialValueFunding = web3.utils.toWei("100", "finney"); //0.1 ETH, required for initial liquidation calculation
    chanceByCommunityInstance = await deployCommunity(deployer, "ChanceBY", "CHANCE", initialTokenMint, initialValueFunding);

    await deployer.deploy(EthKidsRegistry);
    registryInstance = await EthKidsRegistry.deployed();
    console.log('EthKids, EthKidsRegistry: NEW ' + registryInstance.address);

    console.log(`  Registering community in the registry...`);
    await registryInstance.registerCommunity(chanceByCommunityInstance.address);

    console.log('DONE migration');
}