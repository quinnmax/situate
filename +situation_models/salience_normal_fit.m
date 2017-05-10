
function model = salience_normal_fit( p, data_in )

    clear situation_models.salience_normal_draw;
    
    model = situation_models.normal_fit( p, data_in );
    model.salience_model = hmaxq_model_initialize();
    
end















