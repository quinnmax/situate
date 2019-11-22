function records = records_initialize(p,agent_pool)

    records = []; % store information about the run. includes workspace entry event history, scout record, and whatever else you'd like to pass back out
    records.agent_types = {'scout','reviewer','builder'};
    
    current_agent_snapshot_lean = [];
    current_agent_snapshot_lean.type = uint8( 0 );
    current_agent_snapshot_lean.interest = uint8( 0 );
    current_agent_snapshot_lean.box.r0rfc0cf = [0 0 0 0];
    current_agent_snapshot_lean.support = [];
    current_agent_snapshot_lean.workspace = [];
    current_agent_snapshot_lean.workspace.objects = [];
    current_agent_snapshot_lean.workspace.objects_total_support = [];
    
    records.agent_record = repmat( current_agent_snapshot_lean, p.num_iterations, 1 );
    
    records.population_count          = [];
    records.population_count.scout    = 0;
    records.population_count.reviewer = 0;
    records.population_count.builder  = 0;
    
    records.population_count = repmat(records.population_count,p.num_iterations+1,1);
    for agent_type = {'scout','reviewer','builder'}
        if isempty(agent_pool)
            records.population_count(1).(agent_type{:}) = 0;
        else
            records.population_count(1).(agent_type{:}) = sum( strcmp( agent_type{:}, {agent_pool.type} ) );
        end
    end
    
end