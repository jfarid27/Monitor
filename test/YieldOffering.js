const chai = require('chai');
const { expect } = chai;
var chaiAsPromised = require('chai-as-promised');
chai.use(chaiAsPromised);

const { accounts, contract } = require('@openzeppelin/test-environment');
const { singletons, BN, time } = require('@openzeppelin/test-helpers');

const [starter, staker1, staker2] = accounts;

const YO = contract.fromArtifact('YieldOffering');
const MockWETH = contract.fromArtifact('MockWETH');

describe('Yield Offering', function() {
  beforeEach(async function() {
    const currentTime = await time.latest();
    const dt = 5000;
    const initialWethSupply = new BN(`${10 * 10**18}`);
    const initialHourlySupply = new BN(`${1000 * 10**18}`);

    this.yieldRewardStakeToken = await MockWETH.new(initialWethSupply, { from: starter });
    this.yieldOffering = await YO.new(
      new BN(`${currentTime}`),
      new BN(`${currentTime + 2 * dt}`),
      new BN(`${currentTime + 3 * dt}`),
      new BN(`${currentTime + 4 * dt}`),
      new BN(`${currentTime + 5 * dt}`),
      new BN(`${currentTime + 6 * dt}`),
      new BN(`${currentTime + 7 * dt}`),
      new BN(`${currentTime + 8 * dt}`),
      initialHourlySupply,
      this.yieldRewardStakeToken.address,
    {
      from: starter
    });
  });

  describe('initialization', function(){
    it('should properly initialize Stake Pools with a decay of 1 order of magnitude', function() {
      expect(this.yieldOffering.method.pools(1)).to.be.true;
    });
  });
});
