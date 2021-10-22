import {ethers, waffle} from 'hardhat';
import chai from 'chai';

import NFTStakingArtifact from '../artifacts/contracts/NFTStaking.sol/NFTStaking.json';
import {NFTStaking} from '../typechain/NFTStaking';

import TokenRewardArtifact from '../artifacts/contracts/TokenReward.sol/TokenReward.json';
import {TokenReward} from '../typechain/TokenReward';

import GenericNFTArtifact from '../artifacts/contracts/GenericNFT.sol/GenericNFT.json';
import {GenericNFT} from '../typechain/GenericNFT';

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {BigNumber} from '@ethersproject/bignumber';

const {deployContract} = waffle;
const {expect} = chai;

// Utilities methods
const increaseWorldTimeInSeconds = async (seconds: number, mine = false) => {
  await ethers.provider.send('evm_increaseTime', [seconds]);
  if (mine) {
    await ethers.provider.send('evm_mine', []);
  }
};

const SECOND_IN_MONTH = 60 * 60 * 24 * 31;
const PERIOD_IN_DAYS = BigNumber.from(31);
const TOKEN_PER_DAY = ethers.utils.parseEther('3');

describe('NFTStake Contract', () => {
  let owner: SignerWithAddress;
  let addr1: SignerWithAddress;
  let addr2: SignerWithAddress;
  let addr3: SignerWithAddress;
  let addrs: SignerWithAddress[];

  let nftStaking: NFTStaking;
  let tokenReward: TokenReward;
  let genericNFT: GenericNFT;

  beforeEach(async () => {
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

    genericNFT = (await deployContract(owner, GenericNFTArtifact)) as GenericNFT;
    tokenReward = (await deployContract(owner, TokenRewardArtifact)) as TokenReward;
    nftStaking = (await deployContract(owner, NFTStakingArtifact, [tokenReward.address])) as NFTStaking;
    await tokenReward.transferOwnership(nftStaking.address);
  });

  describe('Test stake', () => {
    it('Stake unexisting token', async () => {
      const stakePeriodInMonth = 2;
      const stakeTx = nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);
      await expect(stakeTx).to.be.revertedWith('ERC721: operator query for nonexistent token');
    });
    it("Stake token you don't own", async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr2).mint();
      const stakeTx = nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);
      await expect(stakeTx).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
    });
    it('Stake token you already staked', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();
      // stake nft 1 for 1 month
      // approve it to be transferred to staker contract
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      // try to stake it again
      const stakeTx = nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);
      await expect(stakeTx).to.be.revertedWith('ERC721: transfer of token that is not own');
    });
    it('Create a stake successfully', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();
      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);
      // check owner
      const nftOwner = await genericNFT.ownerOf(1);
      expect(nftOwner).to.equal(nftStaking.address);
      // check token balance
      const balance = await tokenReward.balanceOf(addr1.address);
      expect(balance).to.equal(TOKEN_PER_DAY.mul(PERIOD_IN_DAYS).mul(stakePeriodInMonth));
    });
    it('Create a stake after time unlocked', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      // increase world time
      await increaseWorldTimeInSeconds(SECOND_IN_MONTH * stakePeriodInMonth, true);

      // unstake it
      await nftStaking.connect(addr1).unstake(1);

      const secondPeriodInMonths = 3;
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, secondPeriodInMonths);

      // check owner
      const nftOwner = await genericNFT.ownerOf(1);
      expect(nftOwner).to.equal(nftStaking.address);

      // check token balance
      const balance = await tokenReward.balanceOf(addr1.address);
      expect(balance).to.equal(
        TOKEN_PER_DAY.mul(PERIOD_IN_DAYS)
          .mul(stakePeriodInMonth)
          .add(TOKEN_PER_DAY.mul(PERIOD_IN_DAYS).mul(secondPeriodInMonths)),
      );
    });
  });

  describe('Test NFT transfer', () => {
    it('transfer if staked', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      const stakeTx = genericNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 1);
      await expect(stakeTx).to.be.revertedWith('ERC721: transfer caller is not owner nor approved');
    });

    it('transfer ok after lock period', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      await increaseWorldTimeInSeconds(SECOND_IN_MONTH * stakePeriodInMonth, true);

      // unstake it
      await nftStaking.connect(addr1).unstake(1);

      // transfer it
      await genericNFT.connect(addr1).transferFrom(addr1.address, addr2.address, 1);

      const nftOwner = await genericNFT.ownerOf(1);
      expect(nftOwner).to.equal(addr2.address);
    });
  });

  describe('Test unstake', () => {
    it('unstake unexisting stake record', async () => {
      const unstakeTx = nftStaking.connect(addr1).unstake(1);
      await expect(unstakeTx).to.be.revertedWith('stake record not existing or already redeemed');
    });

    it('unstake already redeemed stake', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      await increaseWorldTimeInSeconds(SECOND_IN_MONTH * stakePeriodInMonth, true);

      // unstake it
      await nftStaking.connect(addr1).unstake(1);

      // unstake it again
      const unstakeTx = nftStaking.connect(addr1).unstake(1);
      await expect(unstakeTx).to.be.revertedWith('stake record not existing or already redeemed');
    });

    it('unstake before lock period expired', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      // unstake it before lock period expired
      const unstakeTx = nftStaking.connect(addr1).unstake(1);

      await expect(unstakeTx).to.be.revertedWith('nft is still locked');
    });

    it('unstake success', async () => {
      const stakePeriodInMonth = 2;
      await genericNFT.connect(addr1).mint();

      // stake nft 1 for 1 month
      await genericNFT.connect(addr1).approve(nftStaking.address, 1);
      await nftStaking.connect(addr1).stake(genericNFT.address, 1, stakePeriodInMonth);

      await increaseWorldTimeInSeconds(SECOND_IN_MONTH * stakePeriodInMonth, true);

      // unstake it
      await nftStaking.connect(addr1).unstake(1);

      // unstake it again
      const nftOwner = await genericNFT.ownerOf(1);
      expect(nftOwner).to.equal(addr1.address);
    });
  });
});
