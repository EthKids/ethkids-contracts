const truffleAssert = require('truffle-assertions');

var ExponentialDeflation = artifacts.require("ExponentialDeflation");
var BondingVault = artifacts.require("BondingVault");
var CharityVault = artifacts.require("CharityVault");
var DonationCommunity = artifacts.require("DonationCommunity");
var EthKidsToken = artifacts.require("EthKidsToken");
var EthKidsRegistry = artifacts.require("EthKidsRegistry");
var KyberConverterMock = artifacts.require("KyberConverterMock");
var ERC20Mintable = artifacts.require("ERC20Mintable");

const empty_address = '0x0000000000000000000000000000000000000000';

contract('EthKids', async (accounts) => {

    const ipfsMessage = "ipfsMessage_placeholder";

    let registry;
    let community;
    let formula;
    let bondingVault;
    let charityVault;
    let token;
    let stableToken;
    let currencyConverter;

    let OWNER = accounts[0];
    let DONOR = accounts[1];
    let DONOR2 = accounts[2];
    let DONOR3 = accounts[3];
    let EXTRA_OWNER = accounts[4];
    let CHARITY_INTERMEDIARY = accounts[5];

    let readableETH = function (wei) {
        return parseFloat(web3.utils.fromWei(wei.toString())).toFixed(5) + ' ETH';
    }

    let readableTokens = function (wei) {
        return parseFloat(web3.utils.fromWei(wei.toString())).toFixed(5) + ' CHANCE';
    }


    before("run initial setup ", async () => {
        console.log(`Starting EthKids...`);

        registry = await EthKidsRegistry.deployed();

        assert.strictEqual((await registry.communityIndex.call()).toString(), "1");

        community = await DonationCommunity.at(await registry.getCommunityAt(0));

        bondingVault = await BondingVault.at(await community.bondingVault.call());

        charityVault = await CharityVault.at(await community.charityVault.call());

        token = await EthKidsToken.at(await community.getEthKidsToken());

        formula = await ExponentialDeflation.at(await bondingVault.bondingCurveFormula.call());

        assert.isTrue(await token.isMinter(bondingVault.address));

        //replace the converter with the mock that uses another ERC as 'stable'
        stableToken = await ERC20Mintable.new();
        currencyConverter = await KyberConverterMock.new(empty_address, empty_address, stableToken.address);
        //mint 100 directly to converter
        await stableToken.mint(currencyConverter.address, web3.utils.toWei('100', 'ether'));
        await registry.registerCurrencyConverter(currencyConverter.address);
        await registry.registerCommunityAt(community.address, 0);

    })

    it("should be able to donate", async () => {
        console.log("(1) My reward: " +
            readableTokens(await community.myReward(web3.utils.toWei('100', 'finney'), {from: DONOR})));

        await community.donate({from: DONOR, value: web3.utils.toWei('100', 'finney')});

        console.log("(1) First donor, got in tokens: " +
            readableTokens(await token.balanceOf(DONOR, {from: DONOR})));

        console.log("(1) First donor, liquidation value ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONOR, {from: DONOR})))));

        //charity fund
        let charityAfter = (await stableToken.balanceOf(charityVault.address)).toString();
        assert.strictEqual(charityAfter, web3.utils.toWei("90", "finney"));
        //personal stats
        let stats = (await charityVault.depositsOf(DONOR)).toString();
        assert.strictEqual(stats, web3.utils.toWei("90", "finney"));
        //global stats
        let globalStats = (await charityVault.sumStats.call()).toString();
        assert.strictEqual(globalStats, web3.utils.toWei("90", "finney"));


        //bonding curve fund
        let bondingCurveAfter = (await web3.eth.getBalance(bondingVault.address)).toString();
        //100 finney there initially
        assert.strictEqual(bondingCurveAfter, web3.utils.toWei("110", "finney"));
    })

    it("should sum up on second donation", async () => {
        console.log("(2) My reward: " +
            readableTokens(await community.myReward(web3.utils.toWei('200', 'finney'), {from: DONOR2})));
        await community.donate({from: DONOR2, value: web3.utils.toWei('200', 'finney')});

        console.log("(2) First donor, liquidation value after another donor ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONOR), {from: DONOR}))));

        console.log("(2) Second donor, got in tokens: " +
            readableTokens(await token.balanceOf(DONOR2), {from: DONOR2}));

        console.log("(2) Second donor, liquidation value ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONOR2), {from: DONOR2}))));

        //charity fund
        let charityAfter = (await stableToken.balanceOf(charityVault.address)).toString();
        assert.strictEqual(charityAfter, web3.utils.toWei("270", "finney"));
        //personal stats
        let stats = (await charityVault.depositsOf(DONOR2)).toString();
        assert.strictEqual(stats, web3.utils.toWei("180", "finney"));
        //global stats
        let globalStats = (await charityVault.sumStats.call()).toString();
        assert.strictEqual(globalStats, web3.utils.toWei("270", "finney"));


        //bonding curve fund
        let bondingCurveAfter = (await web3.eth.getBalance(bondingVault.address)).toString();
        assert.strictEqual(bondingCurveAfter, web3.utils.toWei("130", "finney")); // + 20 finney
    })

    it("should sum up on 3rd donation", async () => {
        console.log("(3) My reward: " +
            readableTokens(await community.myReward(web3.utils.toWei('100', 'finney'), {from: DONOR3})));
        await community.donate({from: DONOR3, value: web3.utils.toWei('100', 'finney')});

        console.log("(3) First donor, liquidation value after another donor ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONOR), {from: DONOR}))));
        console.log("(3) Second donor, liquidation value after another donor ETH: " +
            readableETH((await community.myReturn(await token.balanceOf(DONOR2), {from: DONOR2}))));

        console.log("(3) Third donor, got in tokens: " +
            readableTokens(await token.balanceOf(DONOR3), {from: DONOR3}));
    })

    it("should calculate return on sell", async () => {
        let testTokenAmount = web3.utils.toWei("1", "finney");
        console.log("DONOR balance:" + readableETH(await token.balanceOf(DONOR)));
        console.log("DONOR2 balance:" + readableETH(await token.balanceOf(DONOR2)));
        let returnSmallDonor = (await community.myReturn(testTokenAmount, {from: DONOR}));
        let returnBigDonor = (await community.myReturn(testTokenAmount, {from: DONOR2}));

        console.log("(4) Donors comparison, return for small: " + readableETH(returnSmallDonor));
        console.log("(4) Donors comparison, return for big: " + readableETH(returnBigDonor));

        let returnSmallDonorByOwner = (await community.returnForAddress(testTokenAmount, DONOR));
        assert.strictEqual(returnSmallDonorByOwner.toString(), returnSmallDonor.toString());
    })

    it("should be able to sell", async () => {
        let donorBalanceBefore = Number(await web3.eth.getBalance(DONOR2));
        let donorTokenBalanceBefore = Number(await token.balanceOf(DONOR2));
        let bondingVaultBalanceBefore = Number(await web3.eth.getBalance(bondingVault.address));
        let returnBeforeSell = (await community.myReturn(web3.utils.toWei("150", "finney"), {from: DONOR2}));
        await community.sell(web3.utils.toWei("150", "finney"), {from: DONOR2});//0.15 CHANCE

        //personal ETH balance increased
        assert.isTrue(donorBalanceBefore < Number(await web3.eth.getBalance(DONOR2)));
        //bonding curve ETH balance decreased
        assert.isTrue(bondingVaultBalanceBefore > Number(await web3.eth.getBalance(bondingVault.address)));
        //personal CHANCE balance decreased
        assert.isTrue(donorTokenBalanceBefore > Number(await token.balanceOf(DONOR2)));

        let returnAfterSell = (await community.myReturn(web3.utils.toWei("150", "finney"), {from: DONOR2}));
        console.log("(5) My return before I sell: " + readableETH(returnBeforeSell));
        console.log("(5) My return after I sold: " + readableETH(returnAfterSell));
    })

    it("should be able to pass to charity", async () => {
        let charityFundBefore = Number(await stableToken.balanceOf(charityVault.address));
        let intermediaryBalanceBefore = Number(await stableToken.balanceOf(CHARITY_INTERMEDIARY));

        let tx = await community.passToCharity(web3.utils.toWei("100", "finney"), CHARITY_INTERMEDIARY, ipfsMessage);

        assert.strictEqual(Number(await stableToken.balanceOf(charityVault.address)) + Number(web3.utils.toWei("100", "finney")),
            charityFundBefore);
        assert.strictEqual(Number(await stableToken.balanceOf(CHARITY_INTERMEDIARY)) - Number(web3.utils.toWei("100", "finney")),
            intermediaryBalanceBefore);

        truffleAssert.eventEmitted(tx, 'LogPassToCharity', (ev) => {
            return ev.by === OWNER && ev.intermediary === CHARITY_INTERMEDIARY
                && ev.amount.toString() === web3.utils.toWei("100", "finney") && ev.ipfsHash === ipfsMessage;
        }, 'LogPassToCharity should be emitted with correct parameters');

    })

    it("should be able to sweep the bonding curve vault", async () => {
        //sell all
        await community.sell(await token.balanceOf(DONOR), {from: DONOR});
        await community.sell(await token.balanceOf(DONOR2), {from: DONOR2});
        await community.sell(await token.balanceOf(DONOR3), {from: DONOR3});

        assert.strictEqual((await token.totalSupply()).toString(), "1000000000000000000"); //1 CHANCE, initial one
        console.log("Vault after all sells: " + readableETH(await web3.eth.getBalance(bondingVault.address)));

        //bad guy can't
        try {
            await community.sweepBondingVault({from: DONOR});
            assert.ok(false, 'not authorized!');
        } catch (error) {
            assert.ok(true, 'expected');
        }

        await community.sweepBondingVault();
        assert.isTrue(Number(await web3.eth.getBalance(bondingVault.address)) == 0);
    })

    it("should be able to add an extra community leader", async () => {
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), false);

        await community.addSigner(EXTRA_OWNER);
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), true);
    })

    it("new community leader can pass to charity", async () => {
        //bad guy can't
        try {
            await community.passToCharity(web3.utils.toWei("100", "finney"), CHARITY_INTERMEDIARY, ipfsMessage, {from: CHARITY_INTERMEDIARY});
            assert.ok(false, 'not authorized!');
        } catch (error) {
            assert.ok(true, 'expected');
        }
        await community.passToCharity(web3.utils.toWei("100", "finney"), CHARITY_INTERMEDIARY, ipfsMessage, {from: EXTRA_OWNER});
    })

    it("new leader can renounce from community", async () => {
        await community.renounceSigner({from: EXTRA_OWNER});
        assert.strictEqual(await community.isSigner(EXTRA_OWNER), false);
    })

    it("can replace buy formula", async () => {
        let oldFormula = await bondingVault.bondingCurveFormula.call();

        let newFormula = await ExponentialDeflation.new();
        await community.replaceFormula(newFormula.address);

        assert.strictEqual(await bondingVault.bondingCurveFormula.call(), newFormula.address);
    })

})