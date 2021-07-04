# +
*** Settings ***
Documentation    Robot gets the link to the orders file from user.
...              Downloads the csv file with orders from the web.
...              Opens the orders link provided from the vault.
...              Loops through the data from the orders table and does the following.
...                Orders a robot with a specific characteristics provided in the order.
...                Saves the order HTML receipt as a PDF file.
...                Saves the screenshot of a just ordered robot.
...                Embeds the screenshot of the robot to the PDF receipt.
...              Creates ZIP archive of the receipts and the images.

Library           RPA.Browser.Selenium
Library           RPA.HTTP
LIbrary           RPA.Tables
Library           RPA.HTTP
Library           RPA.PDF
Library           RPA.FileSystem
Library           RPA.Archive
Library           RPA.Dialogs
Library           RPA.Robocloud.Secrets
# -


*** Variables ***
${PDF_TEMP_OUTPUT_DIR}    ${CURDIR}${/}receipts
${PNG_TEMP_OUTPUT_DIR}     ${CURDIR}${/}screenshots
${ZIPPED_OUTPUT}        ${CURDIR}${/}zipped_receipts

*** Keywords ***
Set up the directories
    Create Directory    ${PDF_TEMP_OUTPUT_DIR}
    Create Directory    ${PNG_TEMP_OUTPUT_DIR}
    Create Directory    ${ZIPPED_OUTPUT}

*** Keywords ***
Collect the link to download the orders file from user
    Add text input    link    label= Input the download file link
    ${response}=    Run dialog
    [Return]    ${response.link}

*** Keywords***
Get the url to robot ordering page from vault
    ${secret}=    Get Secret    robot_order_url
    [Return]     ${secret}[url]

*** Keywords ***
Download and read the CSV file
    [Arguments]    ${url}
    ${orders_csv}=  Download    ${url}     overwrite=True
    ${table}=    Read table from CSV    orders.csv
    [Return]    ${table}

*** Keywords ***
Open the order robot page
    [Arguments]    ${url}
    Open Available Browser      ${url}


*** Keywords ***
Check for the modal
    ${cond}=    Run Keyword And Return Status    Element Should Be Visible   class:modal
    IF  ${cond} 
        Click Button    OK
    END

*** Keywords ***
Order one robot
    [Arguments]    ${row}
    Check For The Modal
    Select From List By Value   id:head    ${row}[Head]
    Click Element    id:id-body-${row}[Body]
    Input Text   class:form-control   ${row}[Legs]
    Input Text    id:address    ${row}[Address]
    Click Button    Preview
    Wait Until Page Contains Element    id:robot-preview-image
    Click Button    Order
    Check For A Nasty Error

*** Keywords ***
Check for a nasty error
    FOR    ${i}    IN RANGE    10
        ${present}=  Run Keyword And Return Status    Element Should Be Visible   id:receipt
        IF    ${present} == False
            Click Button    Order
        END
        Exit For Loop If    ${present}
    END

*** Keywords ***
Export the receipt as a PDF
    [Arguments]     ${order_number}
    ${sales_results_html}=    Get Element Attribute    id:receipt    outerHTML
    ${pdf_document}=   Html To Pdf    ${sales_results_html}    ${PDF_TEMP_OUTPUT_DIR}${/}robot_receipt_${order_number}.pdf
    ${receipt}=     Set Variable    ${PDF_TEMP_OUTPUT_DIR}${/}robot_receipt_${order_number}.pdf
    [Return]    ${receipt}

*** Keywords ***
Capture the robot image
    [Arguments]     ${order_number}
    ${robot_pic}=   Screenshot    id:robot-preview-image    ${PNG_TEMP_OUTPUT_DIR}${/}robot_${order_number}.png
    ${screenshot}=  Set Variable    ${PNG_TEMP_OUTPUT_DIR}${/}robot_${order_number}.png
    [Return]      ${screenshot}

*** Keywords ***
Embed the screenshot to PDF receipt
    [Arguments]    ${receipt}       ${screenshot}
    Open PDF   ${receipt}
    Add Watermark Image To Pdf    ${screenshot}   ${receipt} 
    Close PDF  ${receipt}

*** Keywords ***
Make the orders
    ${orders_link} =    Collect the link to download the orders file from user
    ${orders_table}=    Download and read the CSV file      ${orders_link}
    FOR    ${row}    IN    @{orders_table}
        Check for the modal        
        Order one robot     ${row}  
        ${pdf}=     Export the receipt as a PDF      ${row}[Order number]
        ${png}=     Capture the robot image        ${row}[Order number]
        Embed the screenshot to PDF receipt     ${pdf}      ${png}
        Click Button    Order another robot
        END

*** Keywords ***
Create ZIP archive from the receipts
    #Create Directory        ${ZIPPED_OUTPUT}
    Archive Folder With Zip       ${PDF_TEMP_OUTPUT_DIR}      ${ZIPPED_OUTPUT}${/}Receipts_with_screenshots.zip

*** Keywords ***
Cleanup temporary directories and close browser
    Remove Directory    ${PDF_TEMP_OUTPUT_DIR}    True
    Remove Directory    ${PNG_TEMP_OUTPUT_DIR}    True
    Remove File         ${CURDIR}${/}orders.csv
    Close Browser

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Set up the directories
    ${url}=    Get the url to robot ordering page from vault
    Open the order robot page       ${url}
    Make the orders
    Create ZIP archive from the receipts
    Log variables
        Log Many    ${OUTPUT_DIR} 
    [Teardown]     Cleanup temporary directories and close browser
