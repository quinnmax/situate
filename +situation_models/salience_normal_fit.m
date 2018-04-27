
function model = salience_normal_fit( situation_struct, data_in )

    clear situation_models.salience_normal_draw;
    
    model = situation_models.normal_fit( situation_struct, data_in );
    model.salience_model = hmaxq_model_initialize();
    
end















