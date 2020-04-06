classdef RuleComplianceRls < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        name                % Class name
        rlsCompliance       % Simulated compliance release (cfs)
        lakeMendoObj        % Lake Mendocino object
    end
    
    methods
        % CLASS CONSTRUCTOR
        function this = RuleComplianceRls(name,lakeMendoObj)
            this.name = name;
            % Set the referenct to the Lake Mendo Object
            this.lakeMendoObj = lakeMendoObj;
        end
    end
    
    methods(Abstract)
        getRlsCompliance(this,vToday,timeStep,stor)
    end
    
end

