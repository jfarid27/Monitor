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
    const VisionVault = contract.fromArtifact('VisionVault');
    const BancorBondingCurve = contract.fromArtifact('BancorBondingCurve');
    const MockWeth = contract.fromArtifact('MockWeth');
    this.decimals = new BN('1000000000000000000');
    this.startingWeth = (new BN('150')).mul(this.decimals);
    this.bondingCurve = await BancorBondingCurve.new({ from: account1 });
    this.weth = await MockWeth.new(this.startingWeth, { from: account1 });
    this.monitor = await Monitor.new({ from: account1, gasLimit: 12000000 });
    this.visionVault = await VisionVault.new(
      this.weth.address,
      this.monitor.address,
      this.bondingCurve.address,
      { from: account1, gasLimit: 12000000 }
    );
    const visionAddress = await this.visionVault.visionAddress.call();
    await this.monitor.initialize(visionAddress, this.bondingCurve.address, { from: account1 });
    this.vision = await Vision.at(visionAddress);

    /**
     * Sets up both accounts with vision using backed WETH.
     */
    this.generateVision = async function() {
      this.stakeAmount = this.startingWeth.div(new BN('10'));
      await this.weth.transfer(account2, this.stakeAmount, { from: account1 });
      await this.weth.transfer(account3, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.visionVault.address, this.stakeAmount, { from: account1 });
      await this.weth.approve(this.visionVault.address, this.stakeAmount, { from: account2 });
      await this.weth.approve(this.visionVault.address, this.stakeAmount, { from: account3 });
      const trans1 = await this.visionVault.mintVision(this.stakeAmount, { from: account1 });
      const trans2 = await this.visionVault.mintVision(this.stakeAmount, { from: account2 });
      const trans3 = await this.visionVault.mintVision(this.stakeAmount, { from: account3 });
      return [trans1, trans2, trans3];
    };

    /**
     * Removes vision for account1.
     */
    this.withdrawVision = async function() {
      this.withdrawAmount = this.stakeAmount;
      const trans1 = await this.visionVault.burnVision(this.withdrawAmount, { from: account1 });
      return [trans1];
    };

    /**
     * Checks the ERC20 balance of a given address.
     */
    this.checkBalanceEqERC20 = async function (contract, address, expected) {
      const value = await contract.balanceOf(address, { from: address });
      return value.eq(expected);
    };

    /**
     * Creates a market usign the given data.
     */
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
      this.foresightStakeAmount = new BN('1').mul(this.decimals);
      this.expectedReturnYes1 = await this.monitor.getPurchaseReturn(marketIndex, yes, this.foresightStakeAmount);
      this.expectedReturnYes2 = await this.monitor.getPurchaseReturn(marketIndex, yes, this.foresightStakeAmount);
      this.expectedReturnNo1 = await this.monitor.getPurchaseReturn(marketIndex, no, this.foresightStakeAmount);
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account1 });
      const trans1 = await this.monitor.buyPosition(marketIndex, yes, this.foresightStakeAmount, { from: account1 });
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account2 });
      const trans2 = await this.monitor.buyPosition(marketIndex, yes, this.foresightStakeAmount, { from: account2 });
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account3 });
      const trans3 = await this.monitor.buyPosition(marketIndex, no, this.foresightStakeAmount, { from: account3 });
      return [trans1, trans2, trans3];
    };

    this.generateForesight2 = async function(marketIndex, invalid, no, yes) {
      this.foresightStakeAmount = new BN('1').mul(this.decimals);
      this.expectedReturnNo1 = await this.monitor.getPurchaseReturn(marketIndex, no, this.foresightStakeAmount);
      this.expectedReturnNo2 = await this.monitor.getPurchaseReturn(marketIndex, no, this.foresightStakeAmount);
      this.expectedReturnNo3 = await this.monitor.getPurchaseReturn(marketIndex, no, this.foresightStakeAmount);
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account1 });
      const trans1 = await this.monitor.buyPosition(marketIndex, no, this.foresightStakeAmount, { from: account1 });
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account2 });
      const trans2 = await this.monitor.buyPosition(marketIndex, no, this.foresightStakeAmount, { from: account2 });
      await this.vision.approve(this.monitor.address, this.foresightStakeAmount, { from: account3 });
      const trans3 = await this.monitor.buyPosition(marketIndex, no, this.foresightStakeAmount, { from: account3 });
      return [trans1, trans2, trans3];
    }

  });
  describe('Vision Bonding Curve', function() {
    describe('deposit stake for vision', function() {
      beforeEach(async function() {
        await this.generateVision();
      });
      it('should debit correct amount of stake token for main account', async function() {
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, this.startingWeth.sub(this.stakeAmount.mul(new BN('3'))));
        expect(check1).to.be.ok;
      });
      it('should debit correct amount of stake token for other account', async function() {
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
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
      it('should credit correct amount of stake token for main account', async function() {
        const expected = this.startingWeth
          .sub(
            this.stakeAmount.mul(new BN('3'))
          )
          .add(
            this.stakeAmount.mul(new BN('99')).div(new BN('100'))
          );
        const check1 = await this.checkBalanceEqERC20(this.weth, account1, expected);
        expect(check1).to.be.ok;
      });
      it('should credit correct amount of stake token for other account', async function() {
        const check2 = await this.checkBalanceEqERC20(this.weth, account2, new BN('0'));
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
      it('should properly stake first order of yes foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account1.stake.eq(this.foresightStakeAmount)).to.be.ok;
      });
      it('should properly stake second order of yes foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account2.stake.eq(this.foresightStakeAmount)).to.be.ok;
      });
      it('should properly stake first order of no foresight tokens based on the quadratic bonding curve', async function() {
        expect(this.votingTransactions.account3.stake.eq(this.foresightStakeAmount)).to.be.ok;
      });
    });
  });
  describe('Market Finalization', function() {
    beforeEach(async function() {
      await this.generateVision();
      this.currentTime = await time.latest();
      this.one_week = new BN('604800');
      this.timeDelta = this.one_week;
      const [trans] = await this.createMarket(this.currentTime.add(this.timeDelta));
      this.marketCreatedTransactionEvent = trans.receipt.logs[0].args;
      this.marketIndex = this.marketCreatedTransactionEvent.index;
      this.yes = this.marketCreatedTransactionEvent.yesIndex;
      this.no = this.marketCreatedTransactionEvent.noIndex;
      this.invalid = this.marketCreatedTransactionEvent.invalidIndex;
      await time.increase(this.timeDelta.div(new BN('2')));
      const [trans1, trans2, trans3] = await this.generateForesight(this.marketIndex, this.invalid, this.no, this.yes);
    });
    it('should not allow withdrawals until fully finalized', async function() {
      await expectRevert(
        this.monitor.withdrawWinningStake(this.marketIndex, this.yes),
        'Market not finalized.'
      );
    });
    describe('once finalized and a week has past since the winning outcome has taken the lead', function() {
      beforeEach(async function() {
        await time.increase(this.timeDelta.add(this.timeDelta).add(this.timeDelta.mul(new BN('2'))));
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
        expect(trans.receipt.logs[0].args.visionOwed.gt(this.foresightStakeAmount)).to.be.ok;
      });
      it('should allow second winning tokens to be withdrawn', async function() {
        const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.yes, { from: account2 });
        expect(trans.receipt.logs[0].args.visionOwed.gt(this.foresightStakeAmount)).to.be.ok;
      });
    });
    describe('when a new outcome takes the lead', function() {
      beforeEach(async function() {
        await time.increase(this.timeDelta);
        const [trans1, trans2, trans3] = await this.generateForesight2(this.marketIndex, this.yes, this.no, this.invalid);
        this.votingTransactions2 = {
          account1: trans1.receipt.logs[0].args,
          account2: trans2.receipt.logs[0].args,
          account3: trans3.receipt.logs[0].args,
        };
      });
      it('should not allow any tokens to be withdrawn.', async function() {
        await expectRevert(
          this.monitor.withdrawWinningStake(this.marketIndex, this.no, { from: account3 }),
          "Market not finalized."
        );
      });
      describe('once a week has past since the winning outcome has taken the lead and the end time has a week added', function() {
        beforeEach(async function() {
          await time.increase(this.timeDelta.add(this.timeDelta.div(new BN('2'))));
          await this.monitor.finalizeMarket(this.marketIndex, { from: account1 });
        });
        it('should not allow losing tokens to be withdrawn', async function() {
          await expectRevert(
            this.monitor.withdrawWinningStake(this.marketIndex, this.yes, { from: account3 }),
            "Selected token is not redeemable."
          );
        });
        it('should allow first winning tokens to be withdrawn', async function() {
          const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.no, { from: account1 });
          expect(trans.receipt.logs[0].args.visionOwed.gt(this.foresightStakeAmount)).to.be.ok;
        });
        it('should allow second winning tokens to be withdrawn', async function() {
          const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.no, { from: account2 });
          expect(trans.receipt.logs[0].args.visionOwed.gt(this.foresightStakeAmount)).to.be.ok;
        });
        it('should allow third winning tokens to be withdrawn', async function() {
          const trans = await this.monitor.withdrawWinningStake(this.marketIndex, this.no, { from: account3 });
          expect(trans.receipt.logs[0].args.visionOwed.gt(this.foresightStakeAmount.mul(new BN('2')))).to.be.ok;
        });
      });
    });
  });
});
