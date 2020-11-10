var BancorFormula = artifacts.require("BancorFormula");


contract('BancorFormula', async (accounts) => {

    let formula;
    const INITIAL_TOKEN_MINTED = web3.utils.toWei('1000000', 'ether');
    const INITIAL_RESERVE = web3.utils.toWei("10", "finney"); //0.01 ETH
    const CONNECTOR_WEIGHT = 400000; //40%
    const DONATION_AMOUNT = web3.utils.toWei("50", "finney"); //0.05 ETH

    let readableTokens = function (wei) {
        return parseFloat(web3.utils.fromWei(wei.toString())).toFixed(3);
    }

    before("run initial setup ", async () => {
        console.log(`Starting BancorFormula...`);

        formula = await BancorFormula.new();
    })

    it("can calculate CHANCE amount for donations", async () => {
        let tokenSupply = INITIAL_TOKEN_MINTED;
        let vaultBalance = INITIAL_RESERVE;
        let buying = 0;
        let price = 0;
        let outputSupply = '';
        let outputPrice = '';
        for (let i = 1; i < 100; i++) {
            //console.log('MINTED: ' + readableTokens(tokenSupply));
            //console.log('VAULT ETH: ' + readableTokens(vaultBalance));
            //console.log('BUYING ' + readableTokens(buying.toString()));
            //console.log(Number(price).toFixed(25));
            buying = await formula.calculatePurchaseReturn(
                tokenSupply,
                vaultBalance,
                CONNECTOR_WEIGHT,
                DONATION_AMOUNT / 10);      //10% of actual donation goes to vault
            tokenSupply = (BigInt(tokenSupply) + (BigInt)(buying)).toString();
            vaultBalance = (BigInt(vaultBalance) + BigInt(DONATION_AMOUNT / 10)).toString();
            price = (DONATION_AMOUNT / 10) / buying;

            outputSupply = outputSupply + readableTokens(tokenSupply) + ', ';
            outputPrice = outputPrice + Number(price).toFixed(25) + ', ';
        }
        console.log('Supply ' + outputSupply);
        console.log('Price ' + outputPrice);
    })

    /*it("can calculate ETH return for personal holdings 1%-100%", async () => {
        for (let i = 1; i < 100; i++) {
            const selling = await formula.calculateSaleReturn(
                TOKEN_MINTED,                                   //total supply
                web3.utils.toWei(i.toString(), 'ether'),        //personal CHANCE holdings
                CURVE_RESERVE,
                web3.utils.toWei('1', 'ether'));                //amount CHANCE selling
            const liquidatedForEth = selling / (Number)(web3.utils.toWei('1', 'ether'));
            //console.log(liquidatedForEth.toString());
        }
    })*/

})