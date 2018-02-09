function support = AUROC_based( internal, external, varargin )

    learned_models = varargin{1};
    oi = varargin{2};
    
    AUROC = learned_models.classifier_model.AUROCs(oi);
    support = (2*(AUROC-.5)-.1) * internal + ((1 - 2*(AUROC-.5))+.1) * external;
    
end
            