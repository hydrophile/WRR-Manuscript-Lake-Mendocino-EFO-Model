clc
clear
tic
import src.*

%% EXISTING OPERATIONS W/ PROXY RULE
load('Inp/Inp_BaseAssumptions.mat');
load('Inp/Inp_ExistingOpsScenario.mat');
% Create constants object that holds model constant values 
constants = Constants;
% Create Lake Mendocino object
LmEo = LakeMendocino(inputDataBaseModel,constants);
% Create compliance release rule
eoRuleCompliance = RuleComplianceD1610Tucp...
    ('Hi-D1610_Q-Tucp',inputDataComplianceD1610Tucp,LmEo,constants);
LmEo.setRuleComplianceRls(eoRuleCompliance);
% Create Existing Operations flood rule
eoRuleFlood = RuleFloodGuideCurve('LmGuideCurve',guideCurveBase,LmEo,constants);
eoRuleMaxRls = RuleMaxRlsLmWfProxy('LmMaxRls',rlsMaxTbl,qMaxWfProxy,LmEo);
% Set flood rule
LmEo.setRuleFloodRls(eoRuleFlood);
LmEo.setRuleMaxRls(eoRuleMaxRls);
% Add ramp rate rule
eoRampNmfs = RuleRampRateNmfs...
    ('NmfsRampRate',rampRateTbl.Release,rampRateTbl.IROC,rampRateTbl.DROC,50,LmEo);
LmEo.addRuleRampRate(eoRampNmfs);
% Run Model
LmEo = LmEo.runModel();
% Model Results
storEo = LmEo.stor(2:end);                             % EO Storage
qForksEo = LmEo.qForks(2:end);                         % EO Forks flow
qHopEo = LmEo.qHop(2:end);                             % EO Hopland flow
qClovEo = LmEo.qClov(2:end);                           % EO Cloverdale flow
qHldsEo = LmEo.qHlds(2:end);                           % EO Healdsburg flow
rlsCompEo = LmEo.rlsCompliance(2:end);                 % EO compliance release
rlsFloodEo = LmEo.rlsFlood(2:end);                     % EO flood release
rlsTotalEo = LmEo.rlsTotal(2:end);                     % EO total release
rlsSpillEo = LmEo.rlsSpill(2:end);                     % EO spill release
qMinEo = LmEo.qMin(2:end);                             % EO minimum instream flow
guideCurve = LmEo.ruleFloodRls.storGuideCurve(2:end);  % EO guide curve
% Put results into time table
vDate = constants.vDate(2:end,:);
resultsEO = timetable(datetime(vDate),...
    storEo,rlsFloodEo,rlsCompEo,rlsSpillEo,...
    qForksEo,qHopEo,qClovEo,qHldsEo);
% Write to CSV file
writetimetable(resultsEO,'Results/resultsEO.csv')

%% ENSEMBLE FORECAST OPERATIONS
import src.*
import fnc.*
load('Inp/Inp_BaseAssumptions.mat');
load('Inp/Inp_Hindcast_Rfc_POR.mat');
load('Inp/Inp_EnsembleForecastOpsScenario.mat');
% Create constants object that holds model constant values 
constants = Constants;
% Create Lake Mendocino object
LmEfo = LakeMendocino(inputDataBaseModel,constants);
efoRuleCompliance = RuleComplianceD1610Tucp...
    ('Hi-D1610_Q-Tucp',inputDataComplianceD1610Tucp,LmEfo,constants);
LmEfo.setRuleComplianceRls(efoRuleCompliance);
efoRuleFlood = RuleFloodEfo...
    ('efoFloodRule',forecastMatrix,inputDataRiskBased,LmEfo,constants);
efoRuleMaxRls = RuleMaxRlsLmEfo('efoLmMaxRls',rlsMaxTbl,qMaxHopEf,LmEfo);
efoRuleFlood.addRuleMaxRls(efoRuleMaxRls);
% Add ramp rate rule
efoRampNmfs = RuleRampRateNmfs...
    ('NmfsRampRate',rampRateTbl.Release,rampRateTbl.IROC,rampRateTbl.DROC,50,LmEfo);
LmEfo.addRuleRampRate(efoRampNmfs);
efoRuleFlood.addRuleRampRate(efoRampNmfs);
LmEfo.setRuleFloodRls(efoRuleFlood);
LmEfo = LmEfo.runModel();
storEfo = LmEfo.stor(2:end);                             % EFO Storage
qForksEfo = LmEfo.qForks(2:end);                         % EFO Forks flow
qHopEfo = LmEfo.qHop(2:end);                             % EFO Hopland flow
qClovEfo = LmEfo.qClov(2:end);                           % EFO Cloverdale flow
qHldsEfo = LmEfo.qHlds(2:end);                           % EFO Healdsburg flow
rlsCompEfo = LmEfo.rlsCompliance(2:end);                 % EFO compliance release
qMinEfo = LmEfo.qMin(2:end);                             % EFO minimum instream flow
rlsFloodEfo = LmEfo.rlsFlood(2:end);                     % EFO flood release
rlsTotalEfo = LmEfo.rlsTotal(2:end);                     % EFO total release
rlsSpillEfo = LmEfo.rlsSpill(2:end);                     % EFO spill release
% Put results into time table
vDate = constants.vDate(2:end,:);
resultsEFO = timetable(datetime(vDate),...
    storEfo,rlsFloodEfo,rlsCompEfo,rlsSpillEfo,...
    qForksEfo,qHopEfo,qClovEfo,qHldsEfo);
% Write to CSV file
writetimetable(resultsEFO,'Results/resultsEFO.csv')


%% PERFECT FORECAST OPERATIONS
load('Inp/Inp_BaseAssumptions.mat');
load('Inp/Inp_Hindcast_Perfect_POR.mat');
load('Inp/Inp_PerfectForecastScenario.mat');
% Create constants object that holds model constant values 
constants = Constants;
% Create Lake Mendocino object
LmPfo = LakeMendocino(inputDataBaseModel,constants);
pfoRuleCompliance = RuleComplianceD1610Tucp...
    ('Hi-D1610_Q-Tucp',inputDataComplianceD1610Tucp,LmPfo,constants);
LmPfo.setRuleComplianceRls(pfoRuleCompliance);
pfoRuleFlood = RuleFloodEfo...
    ('pfoFloodRule',forecastPerfect,inputDataPerfectForecast,LmPfo,constants);
qMaxHopPf(1:15,1) = 8000;
pfoRuleMaxRls = RuleMaxRlsLmEfo('efoLmMaxRls',rlsMaxTbl,qMaxHopPf,LmPfo);
pfoRuleFlood.addRuleMaxRls(pfoRuleMaxRls);
% Add ramp rate rule
pfoRampNmfs = RuleRampRateNmfs...
    ('NmfsRampRate',rampRateTbl.Release,rampRateTbl.IROC,rampRateTbl.DROC,50,LmPfo);
LmPfo.addRuleRampRate(pfoRampNmfs);
pfoRuleFlood.addRuleRampRate(pfoRampNmfs);
LmPfo.setRuleFloodRls(pfoRuleFlood);
LmPfo = LmPfo.runModel();
storPfo = LmPfo.stor(2:end);                             % PFO Storage
qForksPfo = LmPfo.qForks(2:end);                         % PFO Forks flow
qHopPfo = LmPfo.qHop(2:end);                             % PFO Hopland flow
qClovPfo = LmPfo.qClov(2:end);                           % PFO Cloverdale flow
qHldsPfo = LmPfo.qHlds(2:end);                           % PFO Healdsburg flow
rlsCompPfo = LmPfo.rlsCompliance(2:end);                 % PFO compliance release
qMinPfo = LmPfo.qMin(2:end);                             % PFO minimum instream flow
rlsFloodPfo = LmPfo.rlsFlood(2:end);                     % PFO flood release
rlsTotalPfo = LmPfo.rlsTotal(2:end);                     % PFO total release
rlsSpillPfo = LmPfo.rlsSpill(2:end);                     % PFO spill release
% Put results into time table
vDate = constants.vDate(2:end,:);
resultsPFO = timetable(datetime(vDate),...
    storPfo,rlsFloodPfo,rlsCompPfo,rlsSpillPfo,...
    qForksPfo,qHopPfo,qClovPfo,qHldsPfo);
% Write to CSV file
writetimetable(resultsPFO,'Results/resultsPFO.csv')


%% Post Process Model Results
vDate = constants.vDate(2:end,:);
% May 10 stor - Exceedance
iMay10 = vDate(:,2)==5 & vDate(:,3)==10;
excStorMay10Eo = fnc_eprob(storEo(iMay10));
excStorMay10Ef = fnc_eprob(storEfo(iMay10));
excStorMay10Pf = fnc_eprob(storPfo(iMay10));

% Hopland Flows - Exceedance
excqHopEo = fnc_eprob(qHopEo(2:end));
excqHopEf = fnc_eprob(qHopEfo(2:end));
excqHopPf = fnc_eprob(qHopPfo(2:end));

% Healdsburg Flows - Exceedance
excqHldsEo = fnc_eprob(qHldsEo(2:end));
excqHldsEf = fnc_eprob(qHldsEfo(2:end));
excqHldsPf = fnc_eprob(qHldsPfo(2:end));

toc
