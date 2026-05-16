// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/governance/SkinGovernor.sol";
import "../../src/governance/SkinTimelock.sol";
import "../../src/tokens/CraftToken.sol";

contract SkinGovernorTest is Test {
    SkinGovernor public governor;
    SkinTimelock public timelock;
    CraftToken public craftToken;

    address public admin   = makeAddr("admin");
    address public voter1  = makeAddr("voter1");
    address public voter2  = makeAddr("voter2");
    address public voter3  = makeAddr("voter3");

    uint256 constant VOTER_BALANCE = 1_000_000 * 1e18;

    function setUp() public {
        vm.startPrank(admin);
        craftToken = new CraftToken(admin);

        // Деплоим Timelock
        address[] memory proposers  = new address[](1);
        address[] memory executors  = new address[](1);
        proposers[0] = address(0); // любой может propose через governor
        executors[0] = address(0); // любой может execute
        timelock = new SkinTimelock(2 days, proposers, executors, admin);

        // Деплоим Governor
        governor = new SkinGovernor(IVotes(address(craftToken)), timelock);

        // Даём Governor роль proposer в Timelock
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Выдаём токены голосующим
        craftToken.mint(voter1, VOTER_BALANCE);
        craftToken.mint(voter2, VOTER_BALANCE);
        craftToken.mint(voter3, VOTER_BALANCE);

        craftToken.grantRole(craftToken.MINTER_ROLE(), address(timelock));
        vm.stopPrank();

        // Делегируем голоса себе
        
        vm.prank(voter1);
        craftToken.delegate(voter1);
        vm.prank(voter2);
        craftToken.delegate(voter2);
        vm.prank(voter3);
        craftToken.delegate(voter3);

        // Двигаем блок вперёд чтобы snapshot зафиксировался
        vm.roll(block.number + 1);
    }

    // ─── Helpers ──────────────────────────────────────────────
    function _createProposal() internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        uint256[] memory values  = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);

        targets[0]    = address(craftToken);
        values[0]     = 0;
        calldatas[0]  = abi.encodeWithSignature(
            "mint(address,uint256)",
            admin,
            1000 * 1e18
        );

        vm.prank(voter1);
        proposalId = governor.propose(
            targets, values, calldatas,
            "Proposal: mint 1000 CRAFT to treasury"
        );
    }

    function _passVotingDelay() internal {
        vm.roll(block.number + governor.votingDelay() + 1);
    }

    function _passVotingPeriod() internal {
        vm.roll(block.number + governor.votingPeriod() + 1);
    }

    // ─── Deployment ───────────────────────────────────────────
    function test_GovernorName() public view {
        assertEq(governor.name(), "SkinGovernor");
    }

    function test_VotingDelay() public view {
        assertEq(governor.votingDelay(), 1 days);
    }

    function test_VotingPeriod() public view {
        assertEq(governor.votingPeriod(), 1 weeks);
    }

    function test_QuorumFraction() public view {
        assertEq(governor.quorumNumerator(), 4);
    }

    function test_ProposalThreshold() public view {
        assertEq(governor.proposalThreshold(), 1e18);
    }

    // ─── Propose ──────────────────────────────────────────────
    function test_CreateProposal() public {
        uint256 proposalId = _createProposal();
        assertTrue(proposalId != 0);
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Pending));
    }

    function test_RevertPropose_BelowThreshold() public {
        address poorVoter = makeAddr("poor");
        vm.prank(admin);
        craftToken.mint(poorVoter, 0.5e18); // меньше порога
        vm.prank(poorVoter);
        craftToken.delegate(poorVoter);
        vm.roll(block.number + 1);

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0] = address(craftToken);

        vm.prank(poorVoter);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Poor proposal");
    }

    // ─── Vote ─────────────────────────────────────────────────
    function test_CastVote() public {
        uint256 proposalId = _createProposal();
        _passVotingDelay();

        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Active));

        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = For

        (uint256 against, uint256 forVotes, uint256 abstain) =
            governor.proposalVotes(proposalId);
        assertTrue(forVotes > 0);
        assertEq(against, 0);
        assertEq(abstain, 0);
    }

    function test_VoteAgainst() public {
        uint256 proposalId = _createProposal();
        _passVotingDelay();

        vm.prank(voter1);
        governor.castVote(proposalId, 0); // 0 = Against

        (uint256 against,,) = governor.proposalVotes(proposalId);
        assertTrue(against > 0);
    }

    function test_RevertVote_BeforeDelay() public {
        uint256 proposalId = _createProposal();

        vm.prank(voter1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function test_RevertVote_Twice() public {
        uint256 proposalId = _createProposal();
        _passVotingDelay();

        vm.startPrank(voter1);
        governor.castVote(proposalId, 1);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
        vm.stopPrank();
    }

    // ─── Full lifecycle: propose→vote→queue→execute ───────────
    function test_FullGovernanceLifecycle() public {
        // 1. Propose
        uint256 proposalId = _createProposal();
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Pending));

        // 2. Vote
        _passVotingDelay();
        vm.prank(voter1);
        governor.castVote(proposalId, 1);
        vm.prank(voter2);
        governor.castVote(proposalId, 1);
        vm.prank(voter3);
        governor.castVote(proposalId, 1);

        // 3. Succeeded
        _passVotingPeriod();
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Succeeded));

        // 4. Queue
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(craftToken);
        calldatas[0] = abi.encodeWithSignature("mint(address,uint256)", admin, 1000 * 1e18);

        governor.queue(targets, values, calldatas,
            keccak256(bytes("Proposal: mint 1000 CRAFT to treasury")));
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Queued));

        // 5. Timelock delay (2 дня)
        vm.warp(block.timestamp + 2 days + 1);

        
        // 7. Execute
        uint256 balanceBefore = craftToken.balanceOf(admin);
        governor.execute(targets, values, calldatas,
            keccak256(bytes("Proposal: mint 1000 CRAFT to treasury")));

        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Executed));
        assertEq(craftToken.balanceOf(admin), balanceBefore + 1000 * 1e18);
    }

    // ─── Fuzz ─────────────────────────────────────────────────
    function testFuzz_VotingPowerMatchesBalance(uint256 amount) public {
        amount = bound(amount, 1e18, 1_000_000 * 1e18);
        address voter = makeAddr("fuzzVoter");

        vm.prank(admin);
        craftToken.mint(voter, amount);

        vm.prank(voter);
        craftToken.delegate(voter);

        vm.roll(block.number + 1);
        assertEq(governor.getVotes(voter, block.number - 1), amount);
    }
}