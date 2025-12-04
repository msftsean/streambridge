"""
StreamBridge Function App
Processes crash dump metadata from Logic Apps workflow
"""

import azure.functions as func
import logging
import json
from datetime import datetime
import hashlib

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


@app.route(route="ProcessCrashDump", methods=["POST"])
def process_crash_dump(req: func.HttpRequest) -> func.HttpResponse:
    """
    Process crash dump metadata received from Logic Apps.

    Expected payload:
    {
        "documentId": "unique-id",
        "deviceId": "device-001",
        "region": "eastus",
        "timestamp": "2024-01-15T10:30:00Z",
        "crashDump": {
            "dumpId": "dump-123",
            "errorCode": "0x80004005",
            "stackTrace": "...",
            "processName": "myapp.exe",
            "memoryDumpUrl": "https://..."
        }
    }
    """
    logging.info("ProcessCrashDump function triggered")

    try:
        # Parse request body
        req_body = req.get_json()

        document_id = req_body.get("documentId", "unknown")
        device_id = req_body.get("deviceId", "unknown")
        region = req_body.get("region", "unknown")
        timestamp = req_body.get("timestamp", datetime.utcnow().isoformat())
        crash_dump = req_body.get("crashDump", {})

        logging.info(f"Processing crash dump for device: {device_id}")
        logging.info(f"Document ID: {document_id}")
        logging.info(f"Region: {region}")

        # Simulate crash dump processing
        processing_result = simulate_crash_dump_processing(crash_dump)

        # Build response
        response = {
            "success": True,
            "documentId": document_id,
            "deviceId": device_id,
            "region": region,
            "processedAt": datetime.utcnow().isoformat() + "Z",
            "analysis": processing_result,
            "metadata": {
                "functionName": "ProcessCrashDump",
                "version": "1.0.0",
                "executionTime": "simulated"
            }
        }

        logging.info(f"Crash dump processed successfully: {json.dumps(response)}")

        return func.HttpResponse(
            json.dumps(response),
            status_code=200,
            mimetype="application/json"
        )

    except ValueError as ve:
        logging.error(f"Invalid JSON payload: {str(ve)}")
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "error": "Invalid JSON payload",
                "message": str(ve)
            }),
            status_code=400,
            mimetype="application/json"
        )

    except Exception as e:
        logging.error(f"Error processing crash dump: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "success": False,
                "error": "Processing failed",
                "message": str(e)
            }),
            status_code=500,
            mimetype="application/json"
        )


def simulate_crash_dump_processing(crash_dump: dict) -> dict:
    """
    Simulate crash dump analysis.
    In production, this would call actual analysis services.
    """
    dump_id = crash_dump.get("dumpId", "unknown")
    error_code = crash_dump.get("errorCode", "0x00000000")
    process_name = crash_dump.get("processName", "unknown.exe")
    stack_trace = crash_dump.get("stackTrace", "")

    # Generate a hash of the crash dump for deduplication
    crash_signature = hashlib.sha256(
        f"{error_code}{process_name}{stack_trace[:100]}".encode()
    ).hexdigest()[:16]

    # Simulate extracting metadata
    analysis = {
        "dumpId": dump_id,
        "crashSignature": crash_signature,
        "errorCategory": categorize_error(error_code),
        "severity": determine_severity(error_code),
        "processInfo": {
            "name": process_name,
            "analyzed": True
        },
        "stackTraceAnalysis": {
            "hasStackTrace": len(stack_trace) > 0,
            "frameCount": stack_trace.count("\n") + 1 if stack_trace else 0,
            "topFrame": extract_top_frame(stack_trace)
        },
        "recommendations": generate_recommendations(error_code),
        "isKnownIssue": check_known_issues(crash_signature)
    }

    logging.info(f"Crash analysis complete - Signature: {crash_signature}, Severity: {analysis['severity']}")

    return analysis


def categorize_error(error_code: str) -> str:
    """Categorize error code into a type."""
    error_categories = {
        "0x80004005": "General Failure",
        "0x80070005": "Access Denied",
        "0x8007000E": "Out of Memory",
        "0x80070057": "Invalid Parameter",
        "0xC0000005": "Access Violation",
        "0xC00000FD": "Stack Overflow"
    }
    return error_categories.get(error_code.upper(), "Unknown Error Type")


def determine_severity(error_code: str) -> str:
    """Determine severity based on error code."""
    critical_codes = ["0xC0000005", "0xC00000FD", "0x8007000E"]
    high_codes = ["0x80070005", "0x80004005"]

    if error_code.upper() in critical_codes:
        return "Critical"
    elif error_code.upper() in high_codes:
        return "High"
    else:
        return "Medium"


def extract_top_frame(stack_trace: str) -> str:
    """Extract the top frame from a stack trace."""
    if not stack_trace:
        return "No stack trace available"

    lines = stack_trace.strip().split("\n")
    return lines[0][:100] if lines else "Empty stack trace"


def generate_recommendations(error_code: str) -> list:
    """Generate recommendations based on error code."""
    recommendations = {
        "0x80004005": [
            "Check for recent system updates",
            "Verify application dependencies",
            "Review event logs for additional context"
        ],
        "0x80070005": [
            "Verify user permissions",
            "Check file/folder access rights",
            "Review security policies"
        ],
        "0x8007000E": [
            "Increase available memory",
            "Check for memory leaks",
            "Consider horizontal scaling"
        ],
        "0xC0000005": [
            "Update to latest application version",
            "Check for null pointer issues",
            "Review memory access patterns"
        ]
    }
    return recommendations.get(error_code.upper(), ["Review crash dump manually"])


def check_known_issues(crash_signature: str) -> bool:
    """
    Check if crash signature matches known issues.
    In production, this would query a database.
    """
    # Simulated known issues database
    known_signatures = [
        "a1b2c3d4e5f6g7h8",
        "1234567890abcdef"
    ]
    return crash_signature in known_signatures


@app.route(route="health", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint for monitoring."""
    return func.HttpResponse(
        json.dumps({
            "status": "healthy",
            "service": "StreamBridge Function App",
            "version": "1.0.0",
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }),
        status_code=200,
        mimetype="application/json"
    )
