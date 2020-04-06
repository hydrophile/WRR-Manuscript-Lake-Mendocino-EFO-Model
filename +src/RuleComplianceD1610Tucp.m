classdef RuleComplianceD1610Tucp < src.RuleComplianceRls
    % 11/20/2016
    % Developed by John Mendoza and Chris Delaney
    % This class simulates Lake Mendocino compliance releases for
    % D1610 (Oct16 to Apr31) and TUCP (May1 to Oct15) minimum instream flow
    % requirements.
    
    properties
        hc              % Hydrologic condition
        rlsMin          % Minimum release requirement (cfs)
        minFlowSched    % Minimum instream flow schedule (cfs)
        qBufferSched    % Release buffer schedule (cfs)
        storPvp         % Lake Pillsbury storage for dry spring (ac-ft)
        wscD1610        % Decision 1610 water supply condition
        constants       % Model constants object
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleComplianceD1610Tucp...
                (name,inputData,lakeMendoObj,constants)
             % Call constructor of super class
            this = this@src.RuleComplianceRls(name,lakeMendoObj);
            % Initialize variable for sub class
            this.rlsMin = inputData.MinRelease;
            this.storPvp = inputData.PvpTbl.PvpStorage;
            % Minimum Instream Flow Requirements
            this.minFlowSched(:,1) = inputData.MinFlowTbl.Normal;
            this.minFlowSched(:,2) = inputData.MinFlowTbl.DS1;
            this.minFlowSched(:,3) = inputData.MinFlowTbl.DS2;
            this.minFlowSched(:,4) = inputData.MinFlowTbl.Dry;
            this.minFlowSched(:,5) = inputData.MinFlowTbl.Critical;
            % Minimum Instream Flow buffers
            this.qBufferSched(:,1) = inputData.BufferTbl.Normal;
            this.qBufferSched(:,2) = inputData.BufferTbl.DS1;
            this.qBufferSched(:,3) = inputData.BufferTbl.DS2;
            this.qBufferSched(:,4) = inputData.BufferTbl.Dry;
            this.qBufferSched(:,5) = inputData.BufferTbl.Critical;
            % Water Supply Condition
            this.wscD1610 = inputData.WaterSupplyCondTbl.D1610WSC;
            this.constants = constants;
            this.hc(1:this.constants.nTimeSteps,1) = 1;
        end
        
        % SET THE HYDROLOGIC CONDITION
        function hc = setHydroCond(this,hcPrev,storLm,storPvp,vToday)
            hc = hcPrev;
            % Set the hydrologic condition
            if vToday(1,2) == 6 && vToday(1,3) == 1
                % Check for Dry Spring 2
                if storLm + storPvp < 130000
                    hc = 3;
                    % Check for Dry Spring 1
                elseif storLm + storPvp < 130000
                    hc = 2;
                end
                % Check for Dry Spring 2 after Oct 1
            elseif vToday(1,2) >= 10 && storLm < 30000
                hc = 3;
            end
        end
        
        % COMPLIANCE RELEASES
        function [rlsCompliance,demand,qMin] = getRlsCompliance(this,timeStep,vToday)
            if vToday(1,2) >= 6
                this.hc(timeStep) = this.setHydroCond(this.hc(timeStep-1,1),...
                    this.lakeMendoObj.stor(timeStep-1),...
                    this.storPvp(timeStep-1),vToday);
            end
            hc = this.hc(timeStep);
            % If storage is less than zero then no release
            qMin = this.rlsMin;
            demand = 0;
            if timeStep > this.constants.nTimeSteps - 2
                rlsCompliance = this.lakeMendoObj.rlsCompliance(timeStep - 1);
            else
                 % Set date index variable for the current day
                iToday = this.constants.vDateYear(:,1) == vToday(2) & ...
                    this.constants.vDateYear(:,2) == vToday(3);
                nToday = datenum(vToday);
                vTmw = datevec(nToday+1);
                vNxDay = datevec(nToday+2);
                iTmw = this.constants.vDateYear(:,1) == vTmw(2) & ...
                    this.constants.vDateYear(:,2) == vTmw(3);
                iNxDay = this.constants.vDateYear(:,1) == vNxDay(2) & ...
                    this.constants.vDateYear(:,2) == vNxDay(3);
                % Calculate the flow deficits for each model junction
                defForks = this.lakeMendoObj.qUiWf(timeStep);
                defHop = this.lakeMendoObj.qUiHop(timeStep) - ...
                    this.lakeMendoObj.lossHop(iToday) + defForks;
                defClov = this.lakeMendoObj.qUiClov(timeStep + 1) - ...
                    this.lakeMendoObj.lossClov(iTmw) + defHop;
                defHlds = this.lakeMendoObj.qUiHlds(timeStep + 2) - ...
                    this.lakeMendoObj.lossHlds(iNxDay) + defClov;
                % Determine the controlling node for complying with min flows
                if this.wscD1610(timeStep) == 1
                    qMin = this.minFlowSched(iToday,hc)...
                        + this.qBufferSched(iToday,hc);
                    defControl = qMin - min([defForks,defHop,defClov,defHlds]);
                else
                    qMin = this.minFlowSched(iToday,this.wscD1610(timeStep))...
                        + this.qBufferSched(iToday,this.wscD1610(timeStep));
                    defControl = qMin - min([defForks,defHop,defClov,defHlds]);
                end
                % Calculate downstream demand due to min flows and reach
                % losses:
                demand = max(this.rlsMin,defControl);
                rlsCompliance = ...
                    max(demand - this.lakeMendoObj.rlsFlood(timeStep,1),0);
            end
        end
    end
    
end

