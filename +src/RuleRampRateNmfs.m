classdef RuleRampRateNmfs < src.RuleRampRate
    % 10/13/2016
    % Developed by Chris Delaney
    % Ramp rates defined in the Coyote Valley Dam Water Control Manual and
    % supplemented with updated decreasing rate of change (DROC) rates
    % recommended by the National Marine Fisheries Service in 2015 letter.
    
    properties
        lakeMendoObj            % Lake Mendocino object
        rampRelease             % Release for ramp rate table (cfs)
        rampIroc                % Increasing rate of change for table (cfs/hr)
        rampDroc                % Decreasing rate of change for table (cfs/hr)
        rampMaxDay              % Maximum daily ramping (cfs/day)
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleRampRateNmfs...
                (name,rampRelease,rampIroc,rampDroc,rampMaxDay,lakeMendoObj)
            % Call constructor of super class
            this = this@src.RuleRampRate(name);
            % Initialize subclass variables
            this.lakeMendoObj = lakeMendoObj;
            this.rampRelease = rampRelease;
            this.rampIroc = rampIroc*lakeMendoObj.constants.dT*24;
            this.rampDroc = rampDroc*lakeMendoObj.constants.dT*24;
            this.rampMaxDay = rampMaxDay;
        end
        
        % DETERMINE MAX FLOOD RELEASE
        function [rlsRampRate,rampType] = getAjustedRls(this,vCurTs,rlsCur,rlsPrev)
            nRow = find(this.rampRelease <= rlsPrev,1,'last');
            
            rlsDiff = rlsCur - rlsPrev;
            curTs = datenum(vCurTs);
            mar15 = datenum([vCurTs(1,1) 3 15]);
            may15 = datenum([vCurTs(1,1) 5 15]);
            
            if curTs >= mar15 && curTs <= may15 && nRow == 1 && rlsDiff <= -this.rampMaxDay
                    rampType = 1;
                    rlsRampRate = rlsPrev - this.rampMaxDay;
            elseif rlsDiff < -this.rampDroc(nRow)
                    rampType = 2;
                    rlsRampRate = rlsPrev -this.rampDroc(nRow);
            elseif rlsDiff > this.rampIroc(nRow)
                    rampType = 3;
                rlsRampRate = rlsPrev + this.rampIroc(nRow);
            else
                rampType = 0;
                rlsRampRate = rlsCur;
            end
        end
        
    end
    
end

