protocol ITask {
    
    // MARK: - Methods

    func wait() async
}

extension Task: ITask {
    
    // MARK: - ITask
    
    func wait() async {
        _ = await self.result
    }
}
