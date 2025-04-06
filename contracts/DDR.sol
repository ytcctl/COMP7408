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
    function verify(uint256 caseId, bool isAccepted)  external returns (bool)
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
            bool success = _DDToken.transferFrom(_owner, reportCase.reporter, 1);
            require(success, "Token transfer is failed");
        }

        return true;
    }

    //TODO: complete this function
    function checkCarPlate(string memory carplate) external returns (CaseRecord[] memory) {
        // Hint: also use _iAmNotGuilty
    }

    // TODO: complete this function
    function acquitDriver(uint256 caseId) external {
        // Hint: add to _iAmNotGuilty
    }
}

////////////////////////////////////////////////////////////////////////////
// Q2. Proposed Functions
////////////////////////////////////////////////////////////////////////////
/*
1. Propose function f1, because (background)
function f1 takes inputs: a, b, c and output x.
function f1, can be useful for (practicality)
2. Propose function f2, ...
function f2 takes inputs: a, b, c and output x.
function f2, can be useful for ....
*/