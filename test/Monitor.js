const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time, expectRevert } = require('@openzeppelin/test-helpers');

const [ account1, account2, account3 ] = accounts;

describe('Monitor', function() {
  beforeEach(async function() {
    const erc1820 = await singletons.ERC1820Registry(account1);
    const Monitor = contract.fromArtifact('Monitor');
    const Vision = contract.fromArtifact('Vision');
    const MockWeth = contract.fromArtifact('MockWeth');
    this.startingWeth = (new BN('15000'));
    this.weth = await MockWeth.new(this.startingWeth, { from: account1 });
    this.monitor = await Monitor.new(this.weth.address, { from: account1 });
    await this.monitor.initialize({ from: account1 });
    const visionAddress = await this.monitor.vision.call();
    this.vision = await Vision.at(visionAddress);

    /**
     * Sets up both accounts with vision using backed WETH.
     */
    this.generateVision = async function() {
      this.stakeAmount = this.startingWeth.div(new BN('3'));
      await this.weth.transfer(account2, this.stakeAmount, { from: account1 });
      await this.weth.transfer(account3, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.monitor.address, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.monitor.address, this.stakeAmount, { from: account2 });
      await this.weth.approve(this.monitor.address, this.stakeAmount, { from: account3 });
      const trans1 = await this.monitor.mintVision(this.stakeAmount, { from: account1 });
      const trans2 = await this.monitor.mintVision(this.stakeAmount, { from: account2 });
      const trans3 = await this.monitor.mintVision(this.stakeAmount, { from: account3 });
      return [trans1, trans2, trans3];
    };

    /**
     * Removes vision for account1.
     */
    this.withdrawVision = async function() {
      this.withdrawAmount = this.stakeAmount;
      await this.vision.approve(this.monitor.address, this.withdrawAmount, { from: account1 });
      const trans1 = await this.monitor.burnVision(this.withdrawAmount, { from: account1 });
      return [trans1];
    };

    /**
     * Checks the ERC20 balance of a given address.
     */
    this.checkBalanceEqERC20 = async function (contract, address, expected) {
      const value = await contract.balanceOf(address, { from: address });
      return value.eq(expected);
    };

    this.createMarket = async function(endTime) {
      this.question = "foo";
      this.marketStakeAmount = this.stakeAmount.div(new BN('2'));
      await this.vision.approve(this.monitor.address, this.marketStakeAmount, { from: account1 });
      const trans1 = await this.monitor.createRealityMarket(
        this.question,
        endTime,
        this.marketStakeAmount,
        { from: account1 }
      );
      return [trans1];
    };

    this.generateForesight = async function(marketIndex, invalid, no, yes) {
      this.foresightAmount = new BN('1');
      this.expectedCostYes1 = await this.monitor.computeCostForAmount(new BN('1'), this.foresightAmount);
      this.expectedCostYes2 = await this.monitor.computeCostForAmount(new BN('2'), this.foresightAmount);
      this.expectedCostNo1 = await this.monitor.computeCostForAmount(new BN('1'), this.foresightAmount);
      await this.vision.approve(this.monitor.address, this.expectedCostYes1, { from: account1 });
      const trans1 = await this.monitor.buyPosition(marketIndex, yes, this.foresightAmount, { from: account1 });
      await this.vision.approve(this.monitor.address, this.expectedCostYes2, { from: account2 });
      const trans2 = await this.monitor.buyPosition(marketIndex, yes, this.foresightAmount, { from: account2 });
      await this.vision.approve(this.monitor.address, this.expectedCostNo1, { from: account3 });
      const trans3 = await this.monitor.buyPosition(marketIndex, no, this.foresightAmount, { from: account3 });
      return [trans1, trans2, trans3];
    };

  });
  describe('Vision Bonding Curve', function() {
    describe('deposit stake for vision', function() {
      beforeEach(async function() {
        await this.generateVision();
      });
      it('should debit correct amount of stake token', async function() {
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, new BN('0'));
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
      it('should credit correct amount of Vision', async function() {
        const check1 = await this.checkBalanceEqERC20(this.vision, account1, this.stakeAmount);
        const check2 = await this.checkBalanceEqERC20(this.vision, account2, this.stakeAmount);
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
    });
    describe('withdrawing stake using vision', function() {
      beforeEach(async function() {
        await this.generateVision();
        await this.withdrawVision();
      });
      it('should debit correct amount of vision', async function() {
        const check1 = await this.checkBalanceEqERC20(this.vision, account1, new BN('0'));
        const check2 = await this.checkBalanceEqERC20(this.vision, account2, this.stakeAmount);
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
      it('should credit correct amount of stake token', async function() {
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, this.stakeAmount);
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
        expect(check1).to.be.ok;
        expect(check2).to.be.ok;
      });
    });
  });
  describe('Market Creation', function() {
    beforeEach(async function() {
      await this.generateVision();
      this.currentTime = await time.latest();
    });
    it('should fail if the end time is before the current block', async function (){
      await expectRevert(
        this.createMarket(this.currentTime.sub(new BN('2'))),
        'Market end time cannot be in the past.'
      );
    });
    describe('when given a correctly setup market', function() {
      beforeEach(async function() {
        this.timeDelta = new BN('500000');
        const [trans] = await this.createMarket(this.currentTime.add(this.timeDelta));
        this.marketCreatedTransactionEvent = trans.receipt.logs[0].args;
      });
      it('should properly store market index', function() {
        expect(this.marketCreatedTransactionEvent.index.eq(new BN('1'))).to.be.ok;
      });
      it('should properly generate invalid token index', function() {
        expect(this.marketCreatedTransactionEvent.invalidIndex.eq(new BN('1'))).to.be.ok;
      });
      it('should properly generate no token index', function() {
        expect(this.marketCreatedTransactionEvent.noIndex.eq(new BN('2'))).to.be.ok;
      });
      it('should properly generate yes token index', function() {
        expect(this.marketCreatedTransactionEvent.yesIndex.eq(new BN('3'))).to.be.ok;
      });
      it('should properly stake vision', function() {
        expect(this.marketCreatedTransactionEvent.stake.eq(this.marketStakeAmount)).to.be.ok;
        const currentVisionAmount = this.checkBalanceEqERC20(this.vision, account1, this.marketStakeAmount);
        expect(currentVisionAmount).to.be.ok;
      });
    });
  });
  describe('Market Voting', function() {
    beforeEach(async function(){
      await this.generateVision()
      this.currentTime = await time.latest();
      this.timeDelta = new BN('500000');
      const [trans] = await this.createMarket(this.currentTime.add(this.timeDelta));
      this.marketCreatedTransactionEvent = trans.receipt.logs[0].args;
    });
    describe('transactions', function() {
      beforeEach(async function(){
        this.marketIndex = this.marketCreatedTransactionEvent.index;
        this.yes = this.marketCreatedTransactionEvent.yesIndex;
        this.no = this.marketCreatedTransactionEvent.noIndex;
        this.invalid = this.marketCreatedTransactionEvent.invalidIndex;
        const [trans1, trans2, trans3] = await this.generateForesight(this.marketIndex, this.yes, this.no, this.invalid);
        this.votingTransactions = {
          account1: trans1.receipt.logs[0].args,
          account2: trans2.receipt.logs[0].args,
          account3: trans3.receipt.logs[0].args,
        };
      });
      it('should properly weight first order of yes foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account1.stake.eq(this.expectedCostYes1)).to.be.ok;
      });
      it('should properly weight second order of yes foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account2.stake.eq(this.expectedCostYes2)).to.be.ok;
      });
      it('should properly weight first order of no foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account3.stake.eq(this.expectedCostNo1)).to.be.ok;
      });
    });
  });
  describe('Market Finalization', function() {
    beforeEach(async function() {
      await this.generateVision();
      this.currentTime = await time.latest();
      this.timeDelta = new BN('5000');
      const [trans] = await this.createMarket(this.currentTime.add(this.timeDelta));
      this.marketCreatedTransactionEvent = trans.receipt.logs[0].args;
      this.marketIndex = this.marketCreatedTransactionEvent.index;
      this.yes = this.marketCreatedTransactionEvent.yesIndex;
      this.no = this.marketCreatedTransactionEvent.noIndex;
      this.invalid = this.marketCreatedTransactionEvent.invalidIndex;
      const [trans1, trans2, trans3] = await this.generateForesight(this.marketIndex, this.invalid, this.no, this.yes);
    });
    it('should not allow withdrawals until fully finalized', async function() {
      await expectRevert(
        this.monitor.withdrawWinningStake(this.marketIndex, this.yes),
        'Market not finalized.'
      );
    });
    describe('once finalized', function() {
      beforeEach(async function() {
        await time.increase(this.timeDelta.add(this.timeDelta));
        await this.monitor.finalizeMarket(this.marketIndex, { from: account1 });
      });
      it('should not allow losing tokens to be withdrawn', async function() {
        await expectRevert(
          this.monitor.withdrawWinningStake(this.marketIndex, this.no, { from: account3 }),
          "Selected token is not redeemable."
        );
      });
      it('should not allow users with no winning tokens to withdraw', async function() {
        await expectRevert(
          this.monitor.withdrawWinningStake(this.marketIndex, this.yes, { from: account3 }),
          "User has no stake in the winning outcome."
        );
      });
      it('should allow first winning tokens to be withdrawn', async function() {
        const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.yes, { from: account1 });
        expect(trans.receipt.logs[0].args.visionOwed.gt(this.expectedCostYes1)).to.be.ok;
      });
      it('should allow second winning tokens to be withdrawn', async function() {
        const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.yes, { from: account2 });
        expect(trans.receipt.logs[0].args.visionOwed.gt(this.expectedCostYes2)).to.be.ok;
      });
    });
  });
});
