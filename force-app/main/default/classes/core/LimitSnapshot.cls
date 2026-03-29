/**
 * LimitSnapshot - Captures the current governor limit usage at a point in time.
 * 
 * Automatically reads from Salesforce's Limits class on construction.
 * Used by LimitMonitor to decide whether to continue executing in the
 * current transaction or escalate to a new Queueable.
 * 
 * Also stored in Pipeline_Step_Run__c for post-execution analysis
 * so developers can see exactly how much capacity each step consumed.
 */
public class LimitSnapshot {

    public Integer soqlQueries;
    public Integer soqlQueriesMax;
    public Integer soqlRemaining;

    public Integer dmlStatements;
    public Integer dmlStatementsMax;
    public Integer dmlRemaining;

    public Integer cpuTime;
    public Integer cpuTimeMax;
    public Integer cpuRemaining;

    public Integer heapSize;
    public Integer heapSizeMax;
    public Integer heapRemaining;

    public Integer callouts;
    public Integer calloutsMax;
    public Integer calloutsRemaining;

    public Integer queryRows;
    public Integer queryRowsMax;
    public Integer queryRowsRemaining;

    public Integer dmlRows;
    public Integer dmlRowsMax;
    public Integer dmlRowsRemaining;

    public Integer futureCalls;
    public Integer futureCallsMax;
    public Integer futureRemaining;

    public Integer queueableJobs;
    public Integer queueableJobsMax;
    public Integer queueableRemaining;

    public Long timestamp;

    /**
     * Constructs a snapshot by reading current governor limits.
     */
    public LimitSnapshot() {
        this.timestamp = System.currentTimeMillis();

        this.soqlQueries = Limits.getQueries();
        this.soqlQueriesMax = Limits.getLimitQueries();
        this.soqlRemaining = this.soqlQueriesMax - this.soqlQueries;

        this.dmlStatements = Limits.getDmlStatements();
        this.dmlStatementsMax = Limits.getLimitDmlStatements();
        this.dmlRemaining = this.dmlStatementsMax - this.dmlStatements;

        this.cpuTime = Limits.getCpuTime();
        this.cpuTimeMax = Limits.getLimitCpuTime();
        this.cpuRemaining = this.cpuTimeMax - this.cpuTime;

        this.heapSize = Limits.getHeapSize();
        this.heapSizeMax = Limits.getLimitHeapSize();
        this.heapRemaining = this.heapSizeMax - this.heapSize;

        this.callouts = Limits.getCallouts();
        this.calloutsMax = Limits.getLimitCallouts();
        this.calloutsRemaining = this.calloutsMax - this.callouts;

        this.queryRows = Limits.getQueryRows();
        this.queryRowsMax = Limits.getLimitQueryRows();
        this.queryRowsRemaining = this.queryRowsMax - this.queryRows;

        this.dmlRows = Limits.getDmlRows();
        this.dmlRowsMax = Limits.getLimitDmlRows();
        this.dmlRowsRemaining = this.dmlRowsMax - this.dmlRows;

        this.futureCalls = Limits.getFutureCalls();
        this.futureCallsMax = Limits.getLimitFutureCalls();
        this.futureRemaining = this.futureCallsMax - this.futureCalls;

        this.queueableJobs = Limits.getQueueableJobs();
        this.queueableJobsMax = Limits.getLimitQueueableJobs();
        this.queueableRemaining = this.queueableJobsMax - this.queueableJobs;
    }

    /**
     * Returns the usage percentage (0-100) for a given limit type.
     */
    public Integer getUsagePercent(LimitType limitType) {
        switch on limitType {
            when SOQL { return percent(soqlQueries, soqlQueriesMax); }
            when DML { return percent(dmlStatements, dmlStatementsMax); }
            when CPU { return percent(cpuTime, cpuTimeMax); }
            when HEAP { return percent(heapSize, heapSizeMax); }
            when CALLOUTS { return percent(callouts, calloutsMax); }
            when QUERY_ROWS { return percent(queryRows, queryRowsMax); }
            when DML_ROWS { return percent(dmlRows, dmlRowsMax); }
            when else { return 0; }
        }
    }

    /**
     * Returns true if ANY limit has exceeded the given threshold percentage.
     */
    public Boolean anyLimitExceeds(Integer thresholdPercent) {
        return getUsagePercent(LimitType.SOQL) >= thresholdPercent
            || getUsagePercent(LimitType.DML) >= thresholdPercent
            || getUsagePercent(LimitType.CPU) >= thresholdPercent
            || getUsagePercent(LimitType.HEAP) >= thresholdPercent
            || getUsagePercent(LimitType.CALLOUTS) >= thresholdPercent
            || getUsagePercent(LimitType.QUERY_ROWS) >= thresholdPercent
            || getUsagePercent(LimitType.DML_ROWS) >= thresholdPercent;
        }

    /**
     * Serialize to JSON for storing in Pipeline_Step_Run__c.
     */
    public String toJson() {
        return JSON.serialize(new Map<String, Object>{
            'soql' => soqlQueries + '/' + soqlQueriesMax,
            'dml' => dmlStatements + '/' + dmlStatementsMax,
            'cpu' => cpuTime + '/' + cpuTimeMax + 'ms',
            'heap' => heapSize + '/' + heapSizeMax + 'b',
            'callouts' => callouts + '/' + calloutsMax,
            'queryRows' => queryRows + '/' + queryRowsMax,
            'dmlRows' => dmlRows + '/' + dmlRowsMax,
            'timestamp' => timestamp
        });
    }

    private Integer percent(Integer used, Integer total) {
        if (total == 0) return 0;
        return (Integer) Math.floor((used * 100.0) / total);
    }

    public enum LimitType {
        SOQL,
        DML,
        CPU,
        HEAP,
        CALLOUTS,
        QUERY_ROWS,
        DML_ROWS
    }
}