classdef RuleFloodGuideCurve < src.RuleFloodRls
    % 6/10/2016
    % Developed by Chris Delaney and John Mendoza
    % This Class defines flood operations for the Existing Operations (EO)
    % alternative, which uses the current guide curve Rule.
    
    properties
        guideCurveStor          % Guide curve storage (ac-ft)
        storGuideCurve          % Simulated guide curve as applied (ac-ft)
        constants               % Model constants
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleFloodGuideCurve(name,guideCurveStor,lakeMendoObj,constants)
             % Call constructor of super class
            this = this@src.RuleFloodRls(name,lakeMendoObj);
            % Initialize variable for sub class
            this.guideCurveStor = guideCurveStor;
            this.constants = constants;
            this.storGuideCurve(1:this.constants.nTimeSteps,1) = 0;
        end
        
        % CALCULATE FLOOD RELEASES USING THE GUIDE CURVE
        function rlsFlood = getRlsFlood(this,vToday,timeStep)
            storCur = this.lakeMendoObj.stor(timeStep,1);
            % Initialize flood release to zero
            rlsFlood = 0;
            % Check if storage exceeds rule curve
            iToday = this.constants.vDateYear(:,1) == vToday(2)...
                & this.constants.vDateYear(:,2) == vToday(3);
            this.storGuideCurve(timeStep,1) = this.guideCurveStor(iToday);
            if storCur > this.storGuideCurve(timeStep,1)
                % Increase release to drain flood pool
                rlsFlood = (storCur - this.storGuideCurve(timeStep,1))*this.constants.af2cfs;
            end
            
        end
    end
    
end

