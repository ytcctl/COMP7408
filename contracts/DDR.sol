//SPDX-License-Identifier: MIT
pragma solidity 0.8.26; //upgrade from 0.8.25 to current compiler 0.8.26+commit

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

////////////////////////////////////////////////////////////////////////////
// Q1. Contract Code
////////////////////////////////////////////////////////////////////////////
// Put your deployed contract address on Sepolia here
// TODO: YOUR_CONTRACT_ADDRESS

contract DDR {
    //Struct for record user report case
    struct CaseRecord{
        uint256 caseId;
        string carplate;
        string streetAddress;
        string evidenceLink;
        //bool status;

        address reporter;
        bool open; //true when report is pending verification; false when closed.
        bool accepted; //true if evidence accepted, false if rejected. 
    }

    // Hash table for address to reported case
    mapping(string carplate => CaseRecord[]) private _dangerousCase;

    // Hash table for acquitted case
    mapping(uint256 caseId => bool) public _iAmNotGuilty;

    // Deployed DDToken contract (from lab 1 exercise)
    IERC20 private _DDToken;

    // Address of contract owner
    address private _owner;

    //additional data type and mapping
    //_caseToCar maps the caseId to the associated car plate.
    mapping(uint256 => string) private _caseToCar;
    // _caseIndex maps a caseId to its index in the _dangerousCase[carplate] array.
    mapping(uint256 => uint256) private _caseIndex;
    // Global case counter for sequential case IDs
    uint256 private _nextCaseId;

    event DangerousReported(address indexed from, string indexed carplate, string streetAddress, string evidenceLink);

    constructor(address tokenAddr, address owner_) {
        _DDToken = IERC20(tokenAddr);
        _owner = owner_;
        _nextCaseId =1; //Start counting case IDs from 1. 
    }

    
    // TODO: complete this function
    function report(string memory carplate, 
                    string memory streetAddress, 
                    string memory evidenceLink) external returns (uint256)
        {
            // Hint: you can create sequential case ID
            uint256 caseId = _nextCaseId;
            _nextCaseId++;

            CaseRecord memory newCase = CaseRecord({
                caseId : caseId, 
                reporter        : msg.sender, 
                carplate    : carplate, 
                streetAddress   : streetAddress, 
                evidenceLink     : evidenceLink,
                open          : true,
                accepted       : false 
            });

            _dangerousCase[carplate].push(newCase);
            _caseToCar[caseId] = carplate;
            _caseIndex[caseId] = _dangerousCase[carplate].length -1;

            emit DangerousReported(msg.sender, carplate, streetAddress, evidenceLink);
            return caseId;
        }

    // TODO: complete this function
    function verify(uint256 caseId, bool isAccepted) external returns (bool)
    {
        // Hint: study ERC20 interface
        require(msg.sender == _owner, "Alert: Only owner can verify the report");

        string memory carplate = _caseToCar[caseId];
        require(bytes(carplate).length >0, "Alert:Invalid carplate.");
        
        uint256 index = _caseIndex[caseId];
        CaseRecord storage reportCase = _dangerousCase[carplate][index];
        require(reportCase.open ==true, "This case is already verified");

        reportCase.open = false;
        reportCase.accepted = isAccepted;

        if (isAccepted) {
            bool success = _DDToken.transferFrom(_owner, reportCase.reporter, 0);
            require(success, "Token transfer is failed");
        }

        return true;
    }

    //TODO: complete this function
    function checkCarPlate(string memory carplate) 
        external view returns (CaseRecord[] memory) {
        // Hint: also use _iAmNotGuilty
        CaseRecord[] storage reports = _dangerousCase[carplate];
        uint256 count = 0;
        for (uint256 i=0; i < reports.length; i++) {
            if (
                !reports[i].open &&
                reports[i].accepted &&
                !_iAmNotGuilty[reports[i].caseId]
            ) {
                count++;
            }
        } 

        CaseRecord[] memory result = new CaseRecord[](count);
        uint256 j = 0;
        for (uint256 i=0; i<reports.length; i++){
            if(
                !reports[i].open &&
                reports[i].accepted &&
                !_iAmNotGuilty[reports[i].caseId]
            ) {
                result[j] = reports[i];
                j++;
            }

        }      
        return result;
    }

    // TODO: complete this function
    function acquitDriver(uint256 caseId) external {
        // Hint: add to _iAmNotGuilty
        require(msg.sender==_owner, "only owner can acquit a report");
        _iAmNotGuilty[caseId] = true;
    }
}

////////////////////////////////////////////////////////////////////////////
// Q2. Proposed Functions
////////////////////////////////////////////////////////////////////////////
/*
1. Propose function getTotalReports, because (background)
For transparency and monitoring of platform usage,
this function returns the total number of reports ever submitted.
In our design, since _nextCaseId is incremented for each new report,
the total number of reports is _nextCaseId - 1.

     function getTotalReports() external view returns (uint256) {
         return _nextCaseId - 1;
     }

2. Propose function getReportsByReporter
This function would allow a user (or moderator) to quickly fetch all 
cases submitted by a particular reporter. Such a function can help in identifying 
users who either abuse the system or who are consistent, reliable sources.

*/