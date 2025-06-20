// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // State variables
    address public owner;
    uint256 public policyCounter;
    uint256 public constant PREMIUM_RATE = 5; // 5% of coverage amount
    
    // Structs
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 duration; // in seconds
        bool isActive;
        bool hasClaimed;
    }
    
    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 timestamp;
    }
    
    // Mappings
    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    
    // Events
    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 coverageAmount);
    event PremiumPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(uint256 indexed policyId, address indexed claimant, uint256 claimAmount);
    event ClaimApproved(uint256 indexed policyId, uint256 claimAmount);
    event ClaimPaid(uint256 indexed policyId, address indexed claimant, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId <= policyCounter, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        policyCounter = 0;
    }
    
    // Core Function 1: Create Insurance Policy
    function createPolicy(uint256 _coverageAmount, uint256 _durationInDays) external payable {
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 requiredPremium = (_coverageAmount * PREMIUM_RATE) / 100;
        require(msg.value >= requiredPremium, "Insufficient premium payment");
        
        policyCounter++;
        uint256 duration = _durationInDays * 24 * 60 * 60; // Convert days to seconds
        
        policies[policyCounter] = Policy({
            policyId: policyCounter,
            policyholder: msg.sender,
            coverageAmount: _coverageAmount,
            premiumPaid: msg.value,
            startTime: block.timestamp,
            duration: duration,
            isActive: true,
            hasClaimed: false
        });
        
        userPolicies[msg.sender].push(policyCounter);
        
        emit PolicyCreated(policyCounter, msg.sender, _coverageAmount);
        emit PremiumPaid(policyCounter, msg.sender, msg.value);
    }
    
    // Core Function 2: Submit Insurance Claim
    function submitClaim(uint256 _policyId, uint256 _claimAmount, string memory _description) 
        external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        
        require(msg.sender == policy.policyholder, "Only policyholder can submit claim");
        require(!policy.hasClaimed, "Policy has already been claimed");
        require(block.timestamp <= policy.startTime + policy.duration, "Policy has expired");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        
        claims[_policyId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            isApproved: false,
            isPaid: false,
            timestamp: block.timestamp
        });
        
        emit ClaimSubmitted(_policyId, msg.sender, _claimAmount);
    }
    
    // Core Function 3: Process Insurance Claim (Owner Only)
    function processClaim(uint256 _policyId, bool _approve) external onlyOwner {
        require(claims[_policyId].claimant != address(0), "No claim exists for this policy");
        require(!claims[_policyId].isPaid, "Claim has already been processed");
        
        Claim storage claim = claims[_policyId];
        Policy storage policy = policies[_policyId];
        
        if (_approve) {
            require(address(this).balance >= claim.claimAmount, "Insufficient contract balance");
            
            claim.isApproved = true;
            claim.isPaid = true;
            policy.hasClaimed = true;
            policy.isActive = false;
            
            // Transfer claim amount to claimant
            payable(claim.claimant).transfer(claim.claimAmount);
            
            emit ClaimApproved(_policyId, claim.claimAmount);
            emit ClaimPaid(_policyId, claim.claimant, claim.claimAmount);
        } else {
            // Claim rejected, policy remains active
            claim.isApproved = false;
            claim.isPaid = true; // Mark as processed (rejected)
        }
    }
    
    // Additional utility functions
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }
    
    function getClaimDetails(uint256 _policyId) external view returns (Claim memory) {
        return claims[_policyId];
    }
    
    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        if (_policyId == 0 || _policyId > policyCounter) return false;
        Policy memory policy = policies[_policyId];
        return policy.isActive && (block.timestamp <= policy.startTime + policy.duration);
    }
    
    // Emergency withdrawal function (Owner only)
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
