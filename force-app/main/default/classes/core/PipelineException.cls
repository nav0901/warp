/**
 * PipelineException - Custom exception for the orchestration framework.
 * 
 * Captures step-level context (which step failed, the pipeline context
 * at time of failure) so error handlers have full information to work with.
 */
public class PipelineException extends Exception {

    private String stepId;
    private String pipelineName;
    private PipelineContext ctx;

    public PipelineException(String stepId, String message) {
        this(message);
        this.stepId = stepId;
    }

    public String getStepId() {
        return this.stepId;
    }

    public PipelineException setStepId(String stepId) {
        this.stepId = stepId;
        return this;
    }

    public String getPipelineName() {
        return this.pipelineName;
    }

    public PipelineException setPipelineName(String pipelineName) {
        this.pipelineName = pipelineName;
        return this;
    }

    public PipelineContext getContext() {
        return this.ctx;
    }

    public PipelineException setContext(PipelineContext ctx) {
        this.ctx = ctx;
        return this;
    }
}