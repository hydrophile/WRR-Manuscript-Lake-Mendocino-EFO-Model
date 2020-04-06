classdef LakeMendocino < handle
    % 11/20/2016
    % Developed by Chris Delaney and John Mendoza
    % This class defines all parameters and operations of Lake Mendocino which
    % are independent of the flood alternatives evaluated with this model.
    % These features include: reservoir hypsometry, unimpaired flow hydrology,
    % estimated system water losses, compliance operations,
    % evaporation calculations, uncontrolled spill releases
    % and emergency flood releases.
    
    properties
        % Model input parameters
        name                % Class name
        storBgn             % Beginning simulation storage (ac-ft)
        vDateYear           % Annual date vector for lookup
        spillStor           % Spillway rating curve storage (ac-ft_
        spillQ              % Spillway rating curve flow (cfs)
        outletCurv          % Contolled outlet rating curve (cfs)
        rlsEmgcSched        % Emergency release schedule (cfs)
        qUiLm               % Lake Mendocino unimpaired inflow (cfs)
        qUiWf               % West Fork unimpaired flow (cfs)
        qUiHop              % Hopland unimpaired local flow (cfs)
        qUiClov             % Cloverdale unimpaired local flow (cfs)
        qUiHlds             % Healdsburg unimpaired local flow (cfs)
        rlsPvp              % Specified PVP release (cfs)
        lossLmTot           % Reach losses upstream Lake Mendocino (cfs)
        lossHop             % Reach losses upstream of Hopland (cfs)
        lossClov            % Reach losses betweend Hopland and Cloverdale (cfs)
        lossHlds            % Reach losses betweend Cloverdale and Healdsburg (cfs)
        hypArea             % Lake Mendocino water surface area hypsometry (cfs)
        hypElev             % Lake Mendocino water elevation hypsometry (ft)
        hypStor             % Lake Mendocino storage hypsometry (ac-ft)
        evapRate            % Evaporatio rate (inches)
        ruleComplianceRls   % Compliance release rule object
        ruleFloodRls        % Flood release rule object
        ruleMaxRls          % Maximum release rule object
        ruleRampRate        % Ramp rate rule object
        constants           % Model constants
        % Model calculated variables
        stor                % Simulated storage (ac-ft)
        qMin                % Simulated minimum instream flow (cfs)
        rlsSpill            % Simulated emergency spillway release (cfs)
        rlsEmgc             % Simulated emergecny release (cfs)
        rlsCompliance       % Simulated compliance (water supply) release (cfs)
        rlsFlood            % Simulated flood control release (cfs)
        rlsTotal            % Simuilated total release (cfs)
        rampType            % Simulated ramp rate type
        demand              % Simmulated demand (cfs)
        lossEvap            % Simulated evaporation (ac-ft/day)
        qIn                 % Simulated Lake Mendocino inflow (cfs)
        qForks              % Simulated Forks flow
        qHop                % Simulated Hopland flow
        qClov               % Simulated Cloverdale flow
        qHlds               % Simulated Healdsburg flow
        continuity          % Continuity check
        timeStep            % Model time step
        rowToday            % Row (day of year) for annually repeating data sets
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = LakeMendocino(inputData,constants)
            % Date variable for annually repeating datasets
            vDateYear = inputData.vDateYear;
            vDate = [inputData.UnimpairedFlowTbl.Year...
                inputData.UnimpairedFlowTbl.Month...
                inputData.UnimpairedFlowTbl.Day];
            this.constants = constants;
            this.constants.setConstants(vDate,vDateYear);
            this.name = inputData.AlternativeName;
            this.storBgn = inputData.SimulationBgnStorage;
            % Load Unimpaired Flows
            this.qUiLm = inputData.UnimpairedFlowTbl.LakeMendo;
            this.qUiWf = inputData.UnimpairedFlowTbl.WestFork;
            this.qUiHop = inputData.UnimpairedFlowTbl.Hopland;
            this.qUiClov = inputData.UnimpairedFlowTbl.Cloverdale;
            this.qUiHlds = inputData.UnimpairedFlowTbl.Healdsburg;
            % Potter Valley Project
            this.rlsPvp = inputData.PvpTbl.PvpRelease;
            % System Losses
            % Check if this is an ops model
            this.lossLmTot = inputData.LossTbl.LakeMendo;
            this.lossHop = inputData.LossTbl.Hopland;
            this.lossClov = inputData.LossTbl.Cloverdale;
            this.lossHlds = inputData.LossTbl.Healdsburg;
            % Reservoir hypsometry
            this.hypArea = inputData.HypsometryTbl.Area;
            this.hypElev = inputData.HypsometryTbl.Elevation;
            this.hypStor = inputData.HypsometryTbl.Storage;
            % Controlled Outlet Rating
            this.outletCurv(:,1) = ...
                interp1(this.hypElev,...
                this.hypStor,...
                inputData.OutletCurveTbl.Elev(:),'pchip');
            this.outletCurv(:,2) = inputData.OutletCurveTbl.Release(:);
            % Uncontrolled spill rating
            % Convert spill elevations to storage
            this.spillStor = ...
                interp1(this.hypElev,this.hypStor,inputData.SpillwayTbl.Elevation,'pchip');
            this.spillQ = inputData.SpillwayTbl.Flow;
            % Emergency releases
            % Convert elevation to storages
            this.rlsEmgcSched(:,1) = ...
                interp1(this.hypElev,this.hypStor,inputData.EmergencyReleaseTbl.Elevation,'pchip');
            this.rlsEmgcSched(:,2) = inputData.EmergencyReleaseTbl.Release;
            % Reservoir Evaporation Rate
            this.evapRate(:,1) = inputData.EvapRateTbl.Month;
            this.evapRate(:,2) = inputData.EvapRateTbl.EvapRate;
            % Initialize model calculated variables
            this.stor(1:this.constants.nTimeSteps,1) = NaN;
            this.lossEvap(1:this.constants.nTimeSteps,1) = 0;
            this.rlsCompliance(1:this.constants.nTimeSteps,1) = 0;
            this.demand(1:this.constants.nTimeSteps,1) = 0;
            this.qMin(1:this.constants.nTimeSteps,1) = 0;
            this.rlsFlood(1:this.constants.nTimeSteps,1) = 0;
            this.rlsEmgc(1:this.constants.nTimeSteps,1) = 0;
            this.rlsSpill(1:this.constants.nTimeSteps,1) = 0;
            this.rlsTotal(1:this.constants.nTimeSteps,1) = 0;
            this.rampType(1:this.constants.nTimeSteps,1) = 0;
            this.qIn (1:this.constants.nTimeSteps,1) = 0;
            this.qForks(1:this.constants.nTimeSteps,1) = 0;
            this.qHop(1:this.constants.nTimeSteps,1) = 0;
            this.qClov(1:this.constants.nTimeSteps,1) = 0;
            this.qHlds(1:this.constants.nTimeSteps,1) = 0;
            this.timeStep(1:this.constants.nTimeSteps,1) = NaN;
        end

        function this = setRuleComplianceRls(this,ruleComplianceRls)
            this.ruleComplianceRls = ruleComplianceRls;
        end
        
        function this = setRuleFloodRls(this,ruleFloodRls)
            this.ruleFloodRls = ruleFloodRls;
        end
        
        function this = setRuleMaxRls(this,ruleMaxRls)
            this.ruleMaxRls = ruleMaxRls;
        end
        
        function this = addRuleRampRate(this,ruleRampRate)
            this.ruleRampRate = ruleRampRate;
        end
        
        % CHECK CONTROLLED OUTLET CAPACITY
        function rlsMaxOutlet = getMaxRls(this,stor)
            rlsMaxOutlet = ...
                interp1(this.outletCurv(:,1),this.outletCurv(:,2),stor,'linear');
        end
        
        % CALCULATE STORAGE
        function stor = getStorage(this,rlsTotal)
            stor = this.stor(this.timeStep-1) ...
                - rlsTotal*this.constants.cfs2af ...
                + this.qUiLm(this.timeStep)*this.constants.cfs2af ...
                + this.rlsPvp(this.timeStep)*this.constants.cfs2af ...
                - this.lossLmTot(this.rowToday)*this.constants.cfs2af ...
                - this.lossEvap(this.timeStep);
        end
        
        % SPILLWAY
        function rlsSpill = getRlsSpill(this,stor)
            rlsSpill = 0;
            if stor > this.spillStor(1,1)
                rlsSpill = interp1(this.spillStor,this.spillQ,stor,'pchip');
                if rlsSpill > (stor-this.spillStor(1,1))*this.constants.af2cfs
                    rlsSpill = (stor-this.spillStor(1,1))*this.constants.af2cfs;
                end
            end
        end
        
        % EMERGENCY OPERATIONS
        function rlsEmgc = getRlsEmergency(this,stor,rlsSpill)
            if stor > this.rlsEmgcSched(1,1)
                row = find(this.rlsEmgcSched(:,1) <= stor,1,'last');
                rlsEmgc = this.rlsEmgcSched(row,2);
                % Calculate storage after spill and emergency releases
                stor = stor - (rlsSpill + rlsEmgc)*this.constants.cfs2af;
                % If storage is below the emergency pool then adjust emergency
                % release
                if rlsSpill > 0 && rlsEmgc > 0 && stor < this.rlsEmgcSched(1,1)
                    rlsEmgc = ...
                        rlsEmgc + (stor - this.rlsEmgcSched(1,1))*this.constants.af2cfs;
                    if rlsEmgc < 0
                        rlsEmgc = 0;
                    end
                end
            else
                rlsEmgc = 0;
            end
        end
        
        % GET ELEVATION
        function elev = getElev(this,stor)
            diffStor = abs(this.hypStor - stor);
            [~,minRow] = min(diffStor);
            elev = this.hypElev(minRow,1);
        end
        
        % GET AREA
        function area = getArea(this,stor)
            diffStor = abs(this.hypStor - stor);
            [~,minRow] = min(diffStor);
            area = this.hypArea(minRow,1);
        end
        
        % CONVERT ELEVATION TO STORAGE
        function stor = convertElev2Stor(this,elev)
            diffElev = abs(this.hypElev - elev);
            [~,minRow] = min(diffElev);
            stor = this.hypStor(minRow,1);
        end
        
        % CALCULATE EVAPORATION
        function lossEvap = getEvap(this,vToday,stor)
            iEvap = this.evapRate(:,1) == vToday(2);
            curEvapRate = this.evapRate(iEvap,2);
            areaLM = this.getArea(stor);
            lossEvap = curEvapRate/12 * areaLM;
        end
        
        % CALCULATE DOWNSTREAM FLOWS
        function [qIn,qForks,qHop,qClov,qHlds] = getDsFlows(this)
            qIn = this.qUiLm(this.timeStep) ...
                + this.rlsPvp(this.timeStep) ...
                - this.lossLmTot(this.rowToday) ...
                - this.lossEvap(this.timeStep)*this.constants.af2cfs;
            qForks = this.rlsTotal(this.timeStep)...
                + this.qUiWf(this.timeStep);
            qHop = qForks ...
                + this.qUiHop(this.timeStep)...
                - this.lossHop(this.rowToday);
            qClov = qHop...
                + this.qUiClov(this.timeStep)...
                - this.lossClov(this.rowToday);
            qHlds = qClov...
                + this.qUiHlds(this.timeStep)...
                - this.lossHlds(this.rowToday);
        end
        
        % RUN MODEL
        function this = runModel(this)
            % Set initial storage
            this.stor(1) = this.storBgn;
            for i = 2:this.constants.nTimeSteps
                this.timeStep = i;
                % Define date variables
                vToday = this.constants.vDate(i,1:3);
                this.rowToday = find(this.constants.vDateYear(:,1) == vToday(2) & ...
                    this.constants.vDateYear(:,2) == vToday(3));
                % Calculate evaporative losses
                this.lossEvap(i,1) = ...
                    this.getEvap(vToday,this.stor(i-1));
                % Calculate storage with no release
                rlsTotCur = 0;
                storInit = this.getStorage(rlsTotCur);
                % Get spill release
                this.rlsSpill(i,1) = this.getRlsSpill(storInit);
                % Get emergency release
                this.rlsEmgc(i,1) = ...
                    this.getRlsEmergency(storInit,this.rlsSpill(i,1));
                % Calculate storage after emergency and spill releases
                rlsTotCur = this.rlsSpill(i,1)+this.rlsEmgc(i,1);
                this.stor(i,1) = ...
                    this.getStorage(rlsTotCur);
                % Estimate flood release
                if isa(this.ruleFloodRls,'src.RuleFloodRls')
                    rlsFloodProposed = this.ruleFloodRls.getRlsFlood(vToday,i);
                else
                    rlsFloodProposed = 0;
                end
                % Check flood release against max release constraints
                if rlsFloodProposed > 0 && isa(this.ruleMaxRls,'src.RuleMaxRls')
                    this.rlsFlood(i,1) = this.ruleMaxRls.checkRlsFlood...
                        (i,rlsFloodProposed);
                else
                    this.rlsFlood(i,1) = rlsFloodProposed;
                end
                % Calculate compliance release
                [this.rlsCompliance(i,1),...
                    this.demand(i,1),...
                    this.qMin(i,1)] = ...
                    this.ruleComplianceRls.getRlsCompliance(i,vToday);
                % Check controlled releases for ramp rates
                [rlsRampRate,this.rampType(i)] = ...
                    this.ruleRampRate.getAjustedRls(this.constants.vDate(i,:),...
                    (this.rlsCompliance(i,1) + this.rlsFlood(i,1)),...
                    (this.rlsCompliance(i-1,1) + this.rlsFlood(i-1,1))...
                    );
                rlsAdj = rlsRampRate - (this.rlsCompliance(i,1) + ...
                    this.rlsFlood(i,1));
                % Check controlled outlet constraints
                rlsMaxOutlet = getMaxRls(this,this.stor(i,1));
                rlsAdj = rlsAdj + ...
                    max(0,this.rlsCompliance(i,1)+this.rlsFlood(i,1)+this.rlsEmgc(i,1)-rlsMaxOutlet);
                if rlsAdj ~= 0
                    if this.rlsFlood(i,1) > 0
                        this.rlsFlood(i,1) = ...
                            this.rlsFlood(i,1) + rlsAdj;
                        if this.rlsFlood(i,1) < 0
                            rlsAdj = this.rlsFlood(i,1);
                            this.rlsFlood(i,1) = 0;
                            this.rlsCompliance(i,1) = ...
                                this.rlsCompliance(i,1) + rlsAdj;
                        end
                    else
                        this.rlsCompliance(i,1) = ...
                            this.rlsCompliance(i,1) + rlsAdj;
                    end
                end
                % Calculate storage
                rlsTotCur = ...
                    rlsTotCur + this.rlsFlood(i,1) + this.rlsCompliance(i,1);
                this.stor(i,1) = this.getStorage(rlsTotCur);
                % Check storage less than zero
                if this.stor(i,1) < 0
                    % Yes then reduce flood release
                    this.rlsFlood(i,1) = ...
                        this.rlsFlood(i,1) + this.stor(i,1)*this.constants.af2cfs;
                    % Check flood release less than zero
                    if this.rlsFlood(i,1) < 0
                        % Yes reduce compliance release
                        this.rlsCompliance(i,1) = ...
                            this.rlsCompliance(i,1) + this.rlsFlood(i,1);
                        this.rlsFlood(i,1) = 0;
                    end
                    this.stor(i,1) = 0;
                end
                % Calculate total release
                this.rlsTotal(i,1) = ...
                    this.rlsCompliance(i,1) + this.rlsFlood(i,1)...
                    + this.rlsEmgc(i,1) + this.rlsSpill(i,1);
                % Calculate Downstream Flows
                [this.qIn(i,1),this.qForks(i,1),this.qHop(i,1),this.qClov(i,1),this.qHlds(i,1)] = ...
                    this.getDsFlows();
                % Check for continuity:
                this.continuity(i,1) =...
                    (this.stor(i,1)-this.stor(i-1,1))*this.constants.af2cfs ...
                    + this.rlsTotal(i,1) + this.lossLmTot(this.rowToday,1)...
                    + this.lossEvap(i,1)*this.constants.af2cfs...
                    - this.qUiLm(i,1)...
                    - this.rlsPvp(i,1);
                dispStr = ['timeStep = ' num2str(i) ', ' ...
                    datestr([vToday 0 0 0],'mm/dd/yy') ', ' this.ruleFloodRls.name];
                disp(dispStr)
            end
        end
        
    end
    
end

