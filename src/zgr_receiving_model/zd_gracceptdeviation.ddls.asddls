@EndUserText.label: 'Parametros de aceptacion de desviacion'
define abstract entity ZD_GRAcceptDeviation
{
      @EndUserText.label: 'Motivo'
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_GRDeviationReason', element: 'ReasonId' } }]
      ReasonId : abap.char(4);

      @EndUserText.label: 'Observacion'
      Note     : abap.char(80);
}
