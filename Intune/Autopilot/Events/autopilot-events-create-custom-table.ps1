$subscriptionId = "f1d6****-****-****-****-********82bb"
$resourceGroupName = "rg-endpoint"
$workspace = "log-autopilot-events"

$tableParams = @'
{
    "properties": {
        "schema": {
            "name": "AutopilotEvents_CL",
            "columns": [
                {
                    "name": "TimeGenerated",
                    "type": "DateTime",
                    "description": "Data e hora em que o evento foi gerado"
                },
                {
                    "name": "ID_Autopilot_Event",
                    "type": "String",
                    "description": "ID do evento Autopilot"
                },
                {
                    "name": "Device_ID",
                    "type": "String",
                    "description": "ID do dispositivo"
                },
                {
                    "name": "Event_DateTime",
                    "type": "DateTime",
                    "description": "Data e hora do evento"
                },
                {
                    "name": "Device_Registered_DateTime",
                    "type": "DateTime",
                    "description": "Data e hora de registro do dispositivo"
                },
                {
                    "name": "Enrollment_Start_DateTime",
                    "type": "DateTime",
                    "description": "Data e hora de início da inscrição"
                },
                {
                    "name": "Enrollment_Type",
                    "type": "String",
                    "description": "Tipo de inscrição"
                },
                {
                    "name": "Device_Serial_Number",
                    "type": "String",
                    "description": "Número de série do dispositivo"
                },
                {
                    "name": "Managed_Device_Name",
                    "type": "String",
                    "description": "Nome do dispositivo gerenciado"
                },
                {
                    "name": "User_Principal_Name",
                    "type": "String",
                    "description": "Nome principal do usuário"
                },
                {
                    "name": "Deployment_Profile_Display_Name",
                    "type": "String",
                    "description": "Nome de exibição do perfil de implantação"
                },
                {
                    "name": "Enrollment_State",
                    "type": "String",
                    "description": "Estado da inscrição"
                },
                {
                    "name": "Completion_Page_Configuration_Display_Name",
                    "type": "String",
                    "description": "Nome de exibição da página de conclusão de configuração"
                },
                {
                    "name": "Deployment_State",
                    "type": "String",
                    "description": "Estado da implantação"
                },
                {
                    "name": "Device_Setup_Status",
                    "type": "String",
                    "description": "Status da configuração do dispositivo"
                },
                {
                    "name": "Account_Setup_Status",
                    "type": "String",
                    "description": "Status da configuração da conta"
                },
                {
                    "name": "OS_Version",
                    "type": "String",
                    "description": "Versão do sistema operacional"
                },
                {
                    "name": "Deployment_Duration",
                    "type": "String",
                    "description": "Duração da implantação"
                },
                {
                    "name": "Deployment_Total_Duration",
                    "type": "String",
                    "description": "Duração total da implantação"
                },
                {
                    "name": "Device_Preparation_Duration",
                    "type": "String",
                    "description": "Duração da preparação do dispositivo"
                },
                {
                    "name": "Device_Setup_Duration",
                    "type": "String",
                    "description": "Duração da configuração do dispositivo"
                },
                {
                    "name": "Account_Setup_Duration",
                    "type": "String",
                    "description": "Duração da configuração da conta"
                },
                {
                    "name": "Deployment_Start_DateTime",
                    "type": "DateTime",
                    "description": "Data e hora de início da implantação"
                },
                {
                    "name": "Deployment_End_DateTime",
                    "type": "DateTime",
                    "description": "Data e hora de término da implantação"
                },
                {
                    "name": "Targeted_App_Count",
                    "type": "String",
                    "description": "Número de aplicativos direcionados"
                },
                {
                    "name": "Targeted_Policy_Count",
                    "type": "String",
                    "description": "Número de políticas direcionadas"
                },
                {
                    "name": "Enrollment_Failure_Details",
                    "type": "String",
                    "description": "Detalhes de falha da inscrição"
                }
            ]
        }
    }
}
'@
 
Invoke-AzRestMethod -Path "/subscriptions/$subscriptionId/resourcegroups/$resourceGroupName/providers/microsoft.operationalinsights/workspaces/$workspace/tables/AutopilotEvents_CL?api-version=2021-12-01-preview" -Method PUT -payload $tableParams