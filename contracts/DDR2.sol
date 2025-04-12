// SPDX-License-Identifier: MIT
pragma solidity 0.8.26; //upgrade from 0.8.25 to current compiler 0.8.26+commit

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//////////////////////////////////////////////////////////////////////////////
// DDR Contract for Dangerous Driver Roasted
// 
// This contract allows anonymous users to report dangerous drivers by submitting
// a car plate number, street address, and an evidence link. For every verified
// submission (verified by the contract owner), the reporter is rewarded with 1 DD token
// (deducted from the owner's balance). Users can later check reports for a given car plate.
// An acquit function allows the contract owner to retract an offense record in cases of
// insufficient evidence. Note that the token reward, once given, is not returned.
//
// The below implementation introduces additional state variables and expands the
// CaseRecord struct to track the reporter and verification state.
// We also add a mapping (_caseIdToCarPlate) for quick lookup when verifying or acquitting reports.
//////////////////////////////////////////////////////////////////////////////

contract DDR {
    // Struct for recording a user report.
    // We have expanded the struct to include the reporter address and two flags:
    // - isOpen:  true if the report is pending verification; false once verified.
    // - accepted: set to true if the report is accepted (in which case the reporter gets rewarded).
    struct CaseRecord {
        uint256 caseId;
        string carplate;
        string streetAddress;
        string evidenceLink;
        bool isOpen;      // Report is open (pending verification) when true.
        bool accepted;    // True if the evidence was accepted (reward to be given).
        address reporter; // Address of the user who reported the case.
    }
    
    // Mapping from car plate to an array of reports.
    mapping(string => CaseRecord[]) private _dangerousCase;
    
    // Mapping from case ID (unique per report) to acquitted status.
    // A value of true indicates that the case was acquitted (retracted).
    mapping(uint256 => bool) public _iAmNotGuilty;
    
    // Additional mapping from case ID to car plate for quick lookup in verify and acquit functions.
    mapping(uint256 => string) private _caseIdToCarPlate;
    
    // Deployed DDToken contract (ERC20 token for rewarding reporters).
    IERC20 private _DDToken;
    
    // Contract owner address.
    address private _owner;
    
    // Counter to generate unique case IDs.
    uint256 private _caseIdCounter;
    
    // Reward constant (assumes token decimals = 18, so 1 token == 1e18 units).
    uint256 public constant REWARD_AMOUNT = 1 * 10**18;
    
    // Events for logging major actions.
    event DangerousReported(address indexed from, string indexed carplate, string streetAddress, string evidenceLink);
    event ReportVerified(uint256 caseId, bool accepted);
    event DriverAcquitted(uint256 caseId);
    
    // Constructor takes the deployed DDToken contract address and the owner address.
    constructor(address tokenAddr, address owner_) {
        _DDToken = IERC20(tokenAddr);
        _owner = owner_;
    }
 
    /// @notice Report a dangerous driver by providing car plate, street address, and evidence link.
    /// @return caseId A unique identifier for the report.
    function report(
        string memory carplate,
        string memory streetAddress,
        string memory evidenceLink
    ) external returns (uint256) {
        // Increment the counter for a new case.
        _caseIdCounter++;
        uint256 newCaseId = _caseIdCounter;
        
        // Create a new report record.
        // The report starts open (pending verification) and is not yet accepted.
        CaseRecord memory newRecord = CaseRecord({
            caseId: newCaseId,
            carplate: carplate,
            streetAddress: streetAddress,
            evidenceLink: evidenceLink,
            isOpen: true,
            accepted: false,
            reporter: msg.sender
        });
        
        // Save the report in our mapping.
        _dangerousCase[carplate].push(newRecord);
        // Save the mapping from case ID to car plate.
        _caseIdToCarPlate[newCaseId] = carplate;
        
        emit DangerousReported(msg.sender, carplate, streetAddress, evidenceLink);
        return newCaseId;
    }
 
    /// @notice Verify a report (only callable by the contract owner).
    /// If the evidence is accepted, the reporter is rewarded 1 DD token.
    /// The report is then closed for further modification.
    /// @param caseId The unique identifier of the report to verify.
    /// @param isAccepted A boolean indicating whether the evidence is accepted.
    /// @return success A boolean indicating if the verification succeeded.
    function verify(uint256 caseId, bool isAccepted) external returns (bool) {
        require(msg.sender == _owner, "Only owner can verify reports");
        
        // Retrieve the car plate associated with the report.
        string memory carplate = _caseIdToCarPlate[caseId];
        require(bytes(carplate).length != 0, "Case not found");
        
        // Look for the particular report in the array for this car plate.
        uint256 len = _dangerousCase[carplate].length;
        bool found = false;
        for (uint256 i = 0; i < len; i++) {
            if (_dangerousCase[carplate][i].caseId == caseId) {
                require(_dangerousCase[carplate][i].isOpen, "Report already verified");
                // Close the report.
                _dangerousCase[carplate][i].isOpen = false;
                // Record the verification result.
                _dangerousCase[carplate][i].accepted = isAccepted;
 
                // If the report is accepted, reward 1 DD token (transferred from owner to reporter).
                if (isAccepted) {
                    // Note: the owner must have approved this contract to spend enough tokens.
                    bool success = _DDToken.transferFrom(_owner, _dangerousCase[carplate][i].reporter, REWARD_AMOUNT);
                    require(success, "Token reward transfer failed");
                }
 
                found = true;
                break;
            }
        }
        require(found, "Case record not found");
 
        emit ReportVerified(caseId, isAccepted);
        return true;
    }
 
    /// @notice Check the list of verified, accepted offenses associated with a car plate.
    /// Cases that have been acquitted are removed from the offense list.
    /// @param carplate The car plate number to check.
    /// @return offenses An array of CaseRecord structs representing the offenses.
    function checkCarPlate(string memory carplate) external view returns (CaseRecord[] memory) {
        // Retrieve all reports associated with the provided car plate.
        CaseRecord[] storage reports = _dangerousCase[carplate];
        
        // Count how many reports are verified (closed), accepted, and not acquitted.
        uint256 count = 0;
        for (uint256 i = 0; i < reports.length; i++) {
            if (
                !reports[i].isOpen &&   // report is closed (verified)
                reports[i].accepted &&   // report was accepted
                !_iAmNotGuilty[reports[i].caseId] // report has not been acquitted
            ) {
                count++;
            }
        }
 
        // Build a new array with the filtered results.
        CaseRecord[] memory offenses = new CaseRecord[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < reports.length; i++) {
            if (
                !reports[i].isOpen &&
                reports[i].accepted &&
                !_iAmNotGuilty[reports[i].caseId]
            ) {
                offenses[index] = reports[i];
                index++;
            }
        }
        return offenses;
    }
 
    /// @notice Acquit (retract) an offense record in case of mistake or insufficient evidence.
    /// The token reward that has been distributed will not be returned.
    /// Only the contract owner can perform this action.
    /// @param caseId The unique identifier of the report to acquit.
    function acquitDriver(uint256 caseId) external {
        require(msg.sender == _owner, "Only owner can acquit reports");
        
        // Ensure the case exists by checking its car plate.
        string memory carplate = _caseIdToCarPlate[caseId];
        require(bytes(carplate).length != 0, "Case not found");
        
        _iAmNotGuilty[caseId] = true;
        emit DriverAcquitted(caseId);
    }
    
    // ---------------------------------------------------------------------------------
    // Proposed Additional Functions:
    //
    // 1. function getCaseDetails(uint256 caseId) external view returns (CaseRecord memory)
    //    Rationale: Provide a direct lookup for a case record by its unique ID. This increases
    //    transparency by allowing any user or auditor to retrieve full details of a specific report.
    //
    // 2. function getReportedCarplates() external view returns (string[] memory)
    //    Rationale: Return a list of car plate numbers that have been reported on the platform.
    //    This can help users quickly identify high-risk vehicles on the road. (Note that to implement
    //    this function, an additional state variable such as an array for unique car plates would be required.)
    // ---------------------------------------------------------------------------------
}
