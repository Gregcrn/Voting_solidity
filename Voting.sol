// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

// import of Ownable
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    /**
     * @dev Structure of a person voting
     */
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
        uint256 countOfWon; // V2
    }
    /**
     * @dev Structure of a proposal
     */
    struct Proposal {
        string description;
        uint256 voteCount;
        address proposersAddress; // V2
    }
    /**
     * @dev Different states of a vote
     */
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
    /**
     * @dev Listing of Events
     */
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    /**
     * @dev Listing of variables
     */
    WorkflowStatus public currentStatus;
    uint256 winningProposalId;
    mapping(address => Voter) voters;
    address[] public addressOfVoters;
    Proposal[] public proposals;
    // V2
    address[] public allOfWinners;
    uint256 public nbSession;

    /**
     * @dev constructor initial state
     */
    constructor() {
        currentStatus = WorkflowStatus.RegisteringVoters;
        nbSession = 1;
    }

    /**
     * @dev The voting administrator registers a white list of voters identified by their Ethereum address.
     * @param _adressOfVoters of new voter to add
     */
    function registeredVoter(address _adressOfVoters) external onlyOwner {
        // check Workflow status to begin registered voters session
        require(
            currentStatus == WorkflowStatus.RegisteringVoters,
            "Registration has not yet started or or it's not the right time"
        );
        // check if voter are already registred
        require(
            !voters[_adressOfVoters].isRegistered,
            "You're already registred"
        );
        voters[_adressOfVoters] = Voter(true, false, 0, 0);
        addressOfVoters.push(_adressOfVoters);

        emit VoterRegistered(_adressOfVoters);
    }

    /**
     * @dev The voting administrator begins the proposal registration session.
     */
    function startProposalSession() external onlyOwner {
        // make sure we are in registration period first
        require(
            currentStatus == WorkflowStatus.RegisteringVoters,
            "Registration has not yet started or it's not the right time"
        );
        // change status to ProposalsRegistrationStarted;
        currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
        // use the change of status event
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    /**
     * @dev Registered voters are allowed to register their proposals while the registration session is active
     * params _descriptionOfTheProposal
     */
    function addProposal(string memory _descriptionOfTheProposal) external {
        // check status before making proposals
        require(
            currentStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposal period has not yet started or it's not the right time"
        );
        // check if voter is registered
        require(voters[msg.sender].isRegistered, "You're not registered");
        // add proposal in array of all of proposals
        proposals.push(Proposal(_descriptionOfTheProposal, 0, msg.sender));
        // Take id of proposal
        uint256 proposalId = proposals.length - 1;

        emit ProposalRegistered(proposalId);
    }

    /**
     * @dev The voting administrator closes the proposal registration session.
     */
    function endProposalSession() external onlyOwner {
        // check if we are the right status
        require(
            currentStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "Proposal period has not yet started or it's not the right time"
        );
        // change status to ProposalsRegistrationEnded;
        currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
        // use the change of status event
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    /**
     * @dev The voting administrator begins the voting session.
     */
    function startVotingSession() external onlyOwner {
        // check if the proposal session has close
        require(
            currentStatus == WorkflowStatus.ProposalsRegistrationEnded,
            "Proposal session has not yet close or it's not the right time"
        );
        // change status to VotingSessionStarted
        currentStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    /**
     * @dev Registered voters vote for their preferred proposal.
     * @param _votedId id of proposal to vote
     */
    function voteToFavorite(uint256 _votedId) external {
        // check if we are in the session to vote
        require(
            currentStatus == WorkflowStatus.VotingSessionStarted,
            "You can vote at this time"
        );
        // check if we are the rights to vote
        require(voters[msg.sender].isRegistered, "You cannot vote");
        // check if the voter has not already voted
        require(!voters[msg.sender].hasVoted, "You have already voted");
        // Get proposal id of the vote
        voters[msg.sender].votedProposalId = _votedId;
        // set the status hasVoted at true
        voters[msg.sender].hasVoted = true;
        // add a vote to specific proposal
        proposals[_votedId].voteCount++;
        emit Voted(msg.sender, _votedId);
    }

    /**
     * @dev The voting administrator ends the voting session.
     */
    function VotingSessionEnded() external onlyOwner {
        // check if we are in the right moment
        require(
            currentStatus == WorkflowStatus.VotingSessionStarted,
            "You haven't started voting yet"
        );
        // Change status to VotingSessionEnded
        currentStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    /**
     * @dev The voting administrator counts the votes and return the winning proposal.
     */
    function VotesCounted() external onlyOwner {
        require(
            currentStatus == WorkflowStatus.VotingSessionEnded,
            "Vote session is not over or it's not the right time"
        );

        currentStatus = WorkflowStatus.VotesTallied;

        uint256 winningVoteCount = 0;
        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].voteCount > winningVoteCount) {
                winningVoteCount = proposals[i].voteCount;
                winningProposalId = i;
            }
        }

        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    /**
     * @dev Everyone can check the final details of the winning proposal.
     * @return _description description of winner proposal
     * @return _nbVotes number of votes
     */
    function getDetailsOfWinner()
        external
        view
        returns (string memory _description, uint256 _nbVotes)
    {
        _description = proposals[winningProposalId].description;
        _nbVotes = proposals[winningProposalId].voteCount;
    }

    /**
        -- V2 --
        @dev Return the winner address
        @return _winnerAddress
    */
    function getWinnerAdress() public view returns (address _winnerAddress) {
        _winnerAddress = proposals[winningProposalId].proposersAddress;
    }

    /**
        -- V2 --
        @dev Add one point to the winner 
    */
    function addPointToWinner() external onlyOwner {
        voters[getWinnerAdress()].countOfWon++;
    }

    /**
        -- V2 --
        @dev Stock the winner in Winner's listing
    */
    function addWinnerListing() external onlyOwner {
        require(currentStatus == WorkflowStatus.VotesTallied, "It's to early");
        allOfWinners.push(proposals[winningProposalId].proposersAddress);
    }

    /**
        --V2--
        @dev Restart session and clean data
    */
    function restartSession() external onlyOwner {
        // check if we are in the good moment
        require(
            currentStatus == WorkflowStatus.VotesTallied,
            "Session is not over"
        );
        // Change status to restartSession
        nbSession++;
        for (uint16 i; i < addressOfVoters.length; i++) {
            delete (voters[addressOfVoters[i]]);
        }
        delete (addressOfVoters);
        currentStatus = WorkflowStatus.RegisteringVoters;
        emit WorkflowStatusChange(
            WorkflowStatus.VotesTallied,
            WorkflowStatus.RegisteringVoters
        );
    }
}
