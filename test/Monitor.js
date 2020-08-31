const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time, expectRevert } = require('@openzeppelin/test-helpers');

const [ from, other ] = accounts;

const Vision = contract.fromArtifact('VisionTest');
const Monitor = contract.fromArtifact('Monitor');

describe('Monitor', function() {
  beforeEach(async function() {
    const erc1820 = await singletons.ERC1820Registry(accounts[0]);
    this.vision = await Vision.new({ from: from });
    this.monitor = await Monitor.new(this.vision.address, this.vision.address, { from });
    await this.vision.mint(new BN('5000'), { from });
    await this.vision.mint(new BN('5000'), { from: other })
  });
  describe('when a market is created', function() {
    beforeEach(async function() {
      const currentTime = await time.latest();
      this.currentTime = currentTime;
      this.dt = new BN('500000');
      this.stakeAmount = new BN('100');
      await this.vision.approve(this.monitor.address, this.stakeAmount, { from });
      this.market = await this.monitor.createMarket(
        "Will the sky be blue tomorrow?",
        this.currentTime.add(this.dt),
        this.stakeAmount,
        { from, gasLimit: 10000000 }
      );
    });
    it('should properly store market data', function() {

    });
  });
});
